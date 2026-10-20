// language: Swift 5.9, target: iOS 16+ iPadOS, file: Message.swift
import Foundation

struct Message: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString   // firebase key when read, UUID when cached
    let t: Double                        // epoch millis
    let u: String                        // sender name
    let m: String                        // text

    var time: Date { Date(timeIntervalSince1970: t / 1000) }
}

struct AuthTokens: Codable {
    var idToken: String
    var refreshToken: String
    var expiresAt: Date

    var isExpired: Bool { Date() >= expiresAt }

    static func from(signUp r: SignUpResponse) -> AuthTokens {
        AuthTokens(idToken: r.idToken, refreshToken: r.refreshToken,
                   expiresAt: Date().addingTimeInterval(Double(r.expiresIn) - 120))
    }
    static func from(refresh r: RefreshResponse) -> AuthTokens {
        AuthTokens(idToken: r.id_token, refreshToken: r.refresh_token,
                   expiresAt: Date().addingTimeInterval(Double(r.expires_in) - 120))
    }
}

struct SignUpResponse: Codable {
    let idToken: String
    let refreshToken: String
    let expiresIn: Int
}
struct RefreshResponse: Codable {
    let id_token: String
    let refresh_token: String
    let expires_in: Int
}
struct FirebasePostResult: Codable { let name: String }
