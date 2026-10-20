// language: Swift 5.9, target: iOS 16+ iPadOS, file: ChatViews.swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: ChatModel

    var body: some View {
        if model.room.isEmpty {
            JoinView()
        } else {
            ChatScreen()
        }
    }
}

struct JoinView: View {
    @EnvironmentObject var model: ChatModel
    @State private var name = ""
    @State private var code = ""
    @State private var stage = 0 // 0 name, 1 code

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 90)
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(ChatTheme.blue)
                Text("pocket chat")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)
            }
            Spacer().frame(height: 34)

            if stage == 0 {
                VStack(spacing: 16) {
                    Text("What's your name?")
                        .font(.title3)
                        .foregroundStyle(ChatTheme.nameTint)
                    TextField("name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                        .frame(maxWidth: 260)
                        .onSubmit(advance)
                    Button(action: advance) {
                        Text("continue")
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 26)
                            .padding(.vertical, 11)
                            .background(ChatTheme.blue, in: Capsule())
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 16) {
                    Text("Join a room")
                        .font(.title3)
                        .foregroundStyle(ChatTheme.nameTint)
                    TextField("room code", text: $code)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                        .frame(maxWidth: 260)
                        .onSubmit(join)
                    Button(action: join) {
                        Text("join")
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 26)
                            .padding(.vertical, 11)
                            .background(ChatTheme.blue, in: Capsule())
                    }
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(code.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)

                    Button(action: createRoom) {
                        Text("create a new room")
                            .font(.subheadline)
                            .foregroundStyle(ChatTheme.blue)
                    }
                }
                .transition(.opacity)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChatTheme.background)
        .animation(.easeInOut(duration: 0.2), value: stage)
    }

    private func advance() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        dismissKeyboard_()
        stage = 1
    }

    private func join() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              !code.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        dismissKeyboard_()
        model.join(user: name, roomCode: code)
    }

    private func createRoom() {
        let code = ChatModel.newRoomCode()
        dismissKeyboard_()
        model.join(user: name, roomCode: code)
    }
}
