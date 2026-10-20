// language: Swift 5.9, target: iOS 16+ iPadOS, file: ChatModel.swift
// polling chat over Firebase RTDB REST, anonymous-auth, per-room message cache
import Foundation
import Combine
import UIKit

func dismissKeyboard_() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                     to: nil, from: nil, for: nil)
}

@MainActor
final class ChatModel: ObservableObject {
    @Published var room: String {
        didSet { UserDefaults.standard.set(room, forKey: "room") }
    }
    @Published var user: String {
        didSet { UserDefaults.standard.set(user, forKey: "user") }
    }
    @Published var messages: [Message] = []

    private var tokens: AuthTokens?
    private var inFlight = false

    init() {
        room = UserDefaults.standard.string(forKey: "room") ?? ""
        user = UserDefaults.standard.string(forKey: "user") ?? ""
        loadTokens()
        loadCache()
    }

    // MARK: session

    func join(user name: String, roomCode: String) {
        user = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        room = String(roomCode.trimmingCharacters(in: .whitespacesAndNewlines)
                                        .lowercased().prefix(24))
        messages = []
        saveCache()
        guard !room.isEmpty, !user.isEmpty else { return }
        Task { await poll() }
    }

    func leave() {
        room = ""
        messages = []
        saveCache()
    }

    static func newRoomCode() -> String {
        let chars = Array("abcdefghjkmnpqrstuvwxyz23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    // MARK: tokens

    private var tokensKey: String { "tokens" }

    private func loadTokens() {
        guard let data = UserDefaults.standard.data(forKey: tokensKey),
              let t = try? JSONDecoder().decode(AuthTokens.self, from: data) else { return }
        tokens = t
    }

    private func saveTokens() {
        guard let t = tokens, let data = try? JSONEncoder().encode(t) else { return }
        UserDefaults.standard.set(data, forKey: tokensKey)
    }

    private struct TokenError: Error {}

    private func ensureToken() async throws -> String {
        if let t = tokens, !t.isExpired { return t.idToken }
        var result: AuthTokens
        if let t = tokens, !t.refreshToken.isEmpty {
            result = try await refresh(token: t.refreshToken)
        } else {
            result = try await signUpAnonymous()
        }
        tokens = result
        saveTokens()
        return result.idToken
    }

    private func invalidatetokens() {
        tokens = nil
        UserDefaults.standard.removeObject(forKey: tokensKey)
    }

    private func signUpAnonymous() async throws -> AuthTokens {
        guard let url = URL(string:
            "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(Secrets.firebaseAPIKey)")
        else { throw TokenError() }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["returnSecureToken": true])
        let (data, _) = try await URLSession.shared.data(for: req)
        let res = try JSONDecoder().decode(SignUpResponse.self, from: data)
        return .from(signUp: res)
    }

    private func refresh(token: String) async throws -> AuthTokens {
        guard let url = URL(string:
            "https://securetoken.googleapis.com/v1/token?key=\(Secrets.firebaseAPIKey)")
        else { throw TokenError() }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["grant_type": "refresh_token", "refresh_token": token])
        let (data, _) = try await URLSession.shared.data(for: req)
        let res = try JSONDecoder().decode(RefreshResponse.self, from: data)
        return .from(refresh: res)
    }

    // MARK: REST plumbing

    private var dbBase: String {
        Secrets.firebaseDBURL.hasSuffix("/")
            ? String(Secrets.firebaseDBURL.dropLast())
            : Secrets.firebaseDBURL
    }

    private func buildURL(path: String, query: [URLQueryItem]) async throws -> URL {
        guard var comps = URLComponents(string: "\(dbBase)/\(path)") else { throw TokenError() }
        let t = try await ensureToken()
        comps.queryItems = query + [URLQueryItem(name: "auth", value: t)]
        guard let url = comps.url else { throw TokenError() }
        return url
    }

    // MARK: messages

    func poll() async {
        guard !inFlight, !room.isEmpty else { return }
        inFlight = true
        defer { inFlight = false }
        do {
            let url = try await buildURL(path: "rooms/\(room)/messages.json", query: [
                URLQueryItem(name: "orderBy", value: "\"$key\""),
                URLQueryItem(name: "limitToLast", value: "200"),
            ])
            let (data, response) = try await URLSession.shared.data(for: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                invalidatetokens()
                return
            }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let map = try JSONDecoder().decode([String: Message].self, from: data)
            var fresh = map.map { token in
                var msg = token.value
                msg.id = token.key
                return msg
            }
            fresh.sort { $0.t != $1.t ? $0.t < $1.t : $0.id < $1.id }
            withAnimation(.easeOut(duration: 0.15)) { messages = fresh }
            saveCache()
        } catch {
            // transient network issue — next poll picks it up
        }
    }

    func send(_ text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !room.isEmpty, !user.isEmpty else { return }
        let payload: [String: Any] = [
            "t": Date().timeIntervalSince1970 * 1000,
            "u": user,
            "m": String(clean.prefix(500)),
        ]
        do {
            let url = try await buildURL(path: "rooms/\(room)/messages.json", query: [])
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                invalidatetokens()
            }
            await poll()
        } catch {
            // next poll retries
        }
    }

    // MARK: offline cache

    private var cacheKey: String { "cache_\(room)" }

    private func loadCache() {
        guard !room.isEmpty,
              let data = UserDefaults.standard.data(forKey: cacheKey),
              let arr = try? JSONDecoder().decode([Message].self, from: data) else { return }
        messages = arr
    }

    private func saveCache() {
        guard !room.isEmpty,
              let data = try? JSONEncoder().encode(Array(messages.suffix(300))) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}
