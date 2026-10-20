// language: Swift 5.9, target: iOS 16+ iPadOS, file: ChatAppApp.swift
import SwiftUI

@main
struct ChatAppApp: App {
    @StateObject private var model = ChatModel()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}
