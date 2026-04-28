import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum PikaColor {
    static let background = Color.pikaAdaptive(light: 0xF2F2F4, dark: 0x0B0B0F)
    static let surface = Color.pikaAdaptive(light: 0xFFFFFF, dark: 0x111113)
    static let surfaceAlt = Color.pikaAdaptive(light: 0xF2F2F4, dark: 0x16161A)
    static let surfaceAlt2 = Color.pikaAdaptive(light: 0xE8E8EC, dark: 0x1B1B20)
    static let border = Color.pikaAdaptive(light: 0xE5E5E7, dark: 0x232329)
    static let borderStrong = Color.pikaAdaptive(light: 0xD4D4D8, dark: 0x2E2E36)

    static let textPrimary = Color.pikaAdaptive(light: 0x0A0A0B, dark: 0xF7F7FA)
    static let textSecondary = Color.pikaAdaptive(light: 0x52525B, dark: 0xA1A1AA)
    static let textMuted = Color.pikaAdaptive(light: 0x8E8E93, dark: 0x6B6B75)

    static let accent = Color.pikaAdaptive(light: 0x7B61FF, dark: 0x9B8CFF)
    static let accentHover = Color.pikaAdaptive(light: 0x6F55F2, dark: 0xB2A7FF)
    static let accentMuted = Color.pikaAdaptive(light: 0x7B61FF, lightOpacity: 0.12, dark: 0x9B8CFF, darkOpacity: 0.18)
    static let actionAccent = Color.pikaAdaptive(light: 0x7B61FF, dark: 0xB2A7FF)
    static let actionAccentMuted = Color.pikaAdaptive(light: 0x7B61FF, lightOpacity: 0.10, dark: 0xB2A7FF, darkOpacity: 0.14)
    static let sidebarSelection = Color.pikaAdaptive(light: 0x5423B9, dark: 0x5423B9)
    static let projectDotPalette = [
        Color.pikaAdaptive(light: 0xFF5C7A, dark: 0xFF6F8D),
        Color.pikaAdaptive(light: 0xF97316, dark: 0xFB923C),
        Color.pikaAdaptive(light: 0xD9A30F, dark: 0xFACC15),
        Color.pikaAdaptive(light: 0x2F9E44, dark: 0x74C69D),
        Color.pikaAdaptive(light: 0x0EA5A4, dark: 0x5EEAD4),
        Color.pikaAdaptive(light: 0x0EA5E9, dark: 0x7DD3FC),
        Color.pikaAdaptive(light: 0x3B82F6, dark: 0x93C5FD),
        Color.pikaAdaptive(light: 0x6366F1, dark: 0xA5B4FC),
        Color.pikaAdaptive(light: 0x8B5CF6, dark: 0xC4B5FD),
        Color.pikaAdaptive(light: 0xA855F7, dark: 0xD8B4FE),
        Color.pikaAdaptive(light: 0xD946EF, dark: 0xF0ABFC),
        Color.pikaAdaptive(light: 0xEC4899, dark: 0xF9A8D4),
        Color.pikaAdaptive(light: 0xE11D48, dark: 0xFDA4AF),
        Color.pikaAdaptive(light: 0x14B8A6, dark: 0x99F6E4),
        Color.pikaAdaptive(light: 0x64748B, dark: 0xCBD5E1),
    ]

    static let success = Color.pikaAdaptive(light: 0x2F8F5A, dark: 0x7AC79A)
    static let successMuted = Color.pikaAdaptive(light: 0x2F8F5A, lightOpacity: 0.08, dark: 0x7AC79A, darkOpacity: 0.12)
    static let warning = Color.pikaAdaptive(light: 0xB57A1F, dark: 0xE0B26B)
    static let warningMuted = Color.pikaAdaptive(light: 0xB57A1F, lightOpacity: 0.08, dark: 0xE0B26B, darkOpacity: 0.12)
    static let danger = Color.pikaAdaptive(light: 0xC24545, dark: 0xE07B7B)
    static let dangerMuted = Color.pikaAdaptive(light: 0xC24545, lightOpacity: 0.08, dark: 0xE07B7B, darkOpacity: 0.12)
}

private extension Color {
    static func pikaAdaptive(
        light: UInt,
        lightOpacity: Double = 1,
        dark: UInt,
        darkOpacity: Double = 1
    ) -> Color {
        #if os(macOS)
        Color(nsColor: .init(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor.pikaHex(isDark ? dark : light, opacity: isDark ? darkOpacity : lightOpacity)
        })
        #else
        Color(uiColor: .init { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.pikaHex(dark, opacity: darkOpacity)
                : UIColor.pikaHex(light, opacity: lightOpacity)
        })
        #endif
    }
}

#if os(macOS)
private extension NSColor {
    static func pikaHex(_ hex: UInt, opacity: Double) -> NSColor {
        NSColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: opacity
        )
    }
}
#else
private extension UIColor {
    static func pikaHex(_ hex: UInt, opacity: Double) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: opacity
        )
    }
}
#endif
