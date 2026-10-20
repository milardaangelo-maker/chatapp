// language: Swift 5.9, target: iOS 16+ iPadOS, file: ChatScreen.swift
// iMessage-faithful chat surface: grouped tails, day separators, delivered stamp, exact bar
import SwiftUI

struct ChatScreen: View {
    @EnvironmentObject var model: ChatModel
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                Divider()
                composeBar
                Spacer().frame(height: 2)
            }
            .background(ChatTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundStyle(ChatTheme.blue)
                        Text("room \(model.room)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        model.leave()
                    } label: {
                        Text("leave")
                            .foregroundStyle(ChatTheme.blue)
                    }
                }
            }
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            Task { await model.poll() }
        }
        .task { await model.poll() }
    }

    // MARK: list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(model.messages.enumerated()), id: \.element.id) { idx, msg in
                        if startsNewDay(at: idx) {
                            DaySeparator(date: msg.time)
                                .padding(.top, idx == 0 ? 0 : 12)
                                .padding(.bottom, 4)
                        }
                        BubbleRow(
                            msg: msg,
                            mine: msg.u == model.user,
                            continuesGroup: continuesGroup(at: idx),
                            isLastOfGroup: isLastOfGroup(at: idx),
                            showName: shouldShowName(at: idx)
                        )
                        if idx == model.messages.count - 1 && msg.u == model.user {
                            Text("delivered")
                                .font(.system(size: 11))
                                .foregroundStyle(ChatTheme.delivered)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.trailing, 8)
                                .padding(.top, -1)
                        }
                    }
                    Color.clear.frame(height: 10).id("bottom-anchor")
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
            }
            .onChange(of: model.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo("bottom-anchor", anchor: .bottom)
                }
            }
        }
    }

    private func continuesGroup(at idx: Int) -> Bool {
        guard idx > 0 else { return false }
        return model.messages[idx - 1].u == model.messages[idx].u
    }

    private func isLastOfGroup(at idx: Int) -> Bool {
        guard idx + 1 < model.messages.count else { return true }
        return model.messages[idx + 1].u != model.messages[idx].u
    }

    private func shouldShowName(at idx: Int) -> Bool {
        // group-chat names above a bubble when the sender ranks above the previous line
        !continuesGroup(at: idx) && model.messages[idx].u != model.user
    }

    private func startsNewDay(at idx: Int) -> Bool {
        guard idx > 0 else { return true }
        return !Calendar.current.isDate(model.messages[idx].time,
                                        inSameDayAs: model.messages[idx - 1].time)
    }

    // MARK: iMessage compose bar

    private var composeBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(ChatTheme.nameTint)
                .padding(.bottom, 4)
                .opacity(0.9)

            TextField("iMessage", text: $draft, axis: .vertical)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(UIColor { trait in
                            trait.userInterfaceStyle == .dark
                                ? UIColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1)
                                : UIColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1)
                        }))
                )
                .lineLimit(1...5)
                .onSubmit(send)

            Button(action: send) {
                if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(ChatTheme.nameTint)
                        .opacity(0.35)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(ChatTheme.blue)
                }
            }
            .padding(.bottom, 4)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(ChatTheme.background)
    }

    private func send() {
        let text = draft
        draft = ""
        dismissKeyboard_()
        Task { await model.send(text) }
    }
}

// MARK: rows

struct BubbleRow: View {
    let msg: Message
    let mine: Bool
    let continuesGroup: Bool
    let isLastOfGroup: Bool
    let showName: Bool

    private var maxWidth: CGFloat {
        UIScreen.main.bounds.width * 0.72
    }

    var body: some View {
        VStack(alignment: mine ? .trailing : .leading, spacing: 1) {
            if showName {
                Text(msg.u)
                    .font(.system(size: 12))
                    .foregroundStyle(ChatTheme.nameTint)
                    .padding(.leading, mine ? 0 : 8)
            }
            HStack {
                if mine { Spacer(minLength: 0) }
                Text(msg.m)
                    .font(.system(size: 16))
                    .foregroundStyle(mine ? Color.white : ChatTheme.theirText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        IMessageBubbleShape(mine: mine, hasTail: isLastOfGroup)
                            .fill(mine ? ChatTheme.myBubble : ChatTheme.theirBubble)
                    )
                    .frame(maxWidth: maxWidth, alignment: mine ? .trailing : .leading)
                if !mine { Spacer(minLength: 0) }
            }
        }
        .padding(.top, continuesGroup ? 1 : 8)
        .id(msg.id)
    }
}

struct DaySeparator: View {
    let date: Date

    private var label: String {
        let cal = Calendar.current
        let now = Date()
        let time = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        if cal.isDate(date, inSameDayAs: now) { return time }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: now),
           cal.isDate(date, inSameDayAs: yesterday) {
            return "yesterday " + time
        }
        let df = DateFormatter()
        df.dateFormat = "MMM d, 'at' h:mm a"
        return df.string(from: date)
    }

    var body: some View {
        Text(label)
            .font(.system(size: 11))
            .foregroundStyle(ChatTheme.delivered)
            .frame(maxWidth: .infinity)
    }
}
