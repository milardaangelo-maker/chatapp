// language: Swift 5.9, target: iOS 16+ iPadOS, file: ChatTheme.swift
// iMessage-faithful geometry + palette
import SwiftUI
import UIKit

enum ChatTheme {
    static let blue = Color(red: 11 / 255, green: 147 / 255, blue: 246 / 255)      // #0B93F6
    static let bubbleGrayLight = Color(red: 229 / 255, green: 229 / 255, blue: 234 / 255) // #E5E5EA
    static let bubbleGrayDark = Color(red: 38 / 255, green: 38 / 255, blue: 42 / 255)     // #262626
    static let bgLight = Color.white
    static let bgDark = Color.black

    static var myBubble: Color { blue }
    static var theirBubble: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(ChatTheme.bubbleGrayDark) : UIColor(ChatTheme.bubbleGrayLight)
        })
    }
    static var theirText: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
        })
    }
    static var background: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(Theme.bgDark) : UIColor(Theme.bgLight)
        })
    }
    static var delivered: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1)
                : UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1)
        })
    }
    static var nameTint: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.70, green: 0.70, blue: 0.74, alpha: 1)
                : UIColor(red: 0.40, green: 0.40, blue: 0.44, alpha: 1)
        })
    }
}

private enum Theme {
    static let bgDark = Color.black
    static let bgLight = Color.white
}

// iMessage bubble: 18pt corners, ~4pt "tail" corner on the group's last bubble side
struct IMessageBubbleShape: Shape {
    let mine: Bool
    let hasTail: Bool

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let r: CGFloat = 18
        let tail: CGFloat = max(4, r * 0.22)

        // corner radii: [TL, TR, BR, BL]
        let tailR: CGFloat = hasTail ? tail : r
        let tl = r
        let tr = r
        let br = mine ? tailR : r
        let bl = mine ? r : tailR

        var p = Path()
        p.move(to: CGPoint(x: tl, y: 0))
        p.addLine(to: CGPoint(x: w - tr, y: 0))
        p.addArc(center: CGPoint(x: w - tr, y: tr), radius: tr,
                 startAngle: Angle(degrees: 270), endAngle: Angle(degrees: 0),
                 clockwise: true)
        p.addLine(to: CGPoint(x: w, y: h - br))
        p.addArc(center: CGPoint(x: w - br, y: h - br), radius: br,
                 startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90),
                 clockwise: true)
        p.addLine(to: CGPoint(x: bl, y: h))
        p.addArc(center: CGPoint(x: bl, y: h - bl), radius: bl,
                 startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180),
                 clockwise: true)
        p.addLine(to: CGPoint(x: 0, y: tl))
        p.addArc(center: CGPoint(x: tl, y: tl), radius: tl,
                 startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270),
                 clockwise: true)
        p.closeSubpath()
        return p
    }
}
