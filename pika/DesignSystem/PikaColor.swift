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

    static let accent = Color.pikaAdaptive(light: 0x6D28D9, dark: 0x6D28D9)
    static let accentHover = Color.pikaAdaptive(light: 0x5B21B6, dark: 0x7C3AED)
    static let accentMuted = Color.pikaAdaptive(light: 0x6D28D9, lightOpacity: 0.12, dark: 0x6D28D9, darkOpacity: 0.20)

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
