import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum BillbiColor {
    static let background = Color.billbiAdaptive(light: 0xF2F2F4, dark: 0x0B0B0F)
    static let surface = Color.billbiAdaptive(light: 0xFFFFFF, dark: 0x111113)
    static let surfaceAlt = Color.billbiAdaptive(light: 0xF2F2F4, dark: 0x16161A)
    static let surfaceAlt2 = Color.billbiAdaptive(light: 0xE8E8EC, dark: 0x1B1B20)
    #if os(macOS)
    static let inputSurface = Color(nsColor: .controlBackgroundColor)
    #else
    static let inputSurface = Color(uiColor: .secondarySystemBackground)
    #endif
    static let border = Color.billbiAdaptive(light: 0xE5E5E7, dark: 0x232329)
    static let borderStrong = Color.billbiAdaptive(light: 0xD4D4D8, dark: 0x2E2E36)

    static let textPrimary = Color.billbiAdaptive(light: 0x0A0A0B, dark: 0xF7F7FA)
    static let textSecondary = Color.billbiAdaptive(light: 0x52525B, dark: 0xA1A1AA)
    static let textMuted = Color.billbiAdaptive(light: 0x8E8E93, dark: 0x6B6B75)

    static let brand = Color.billbiAdaptive(light: 0x7B61FF, dark: 0x9B8CFF)
    static let brandMuted = Color.billbiAdaptive(light: 0x7B61FF, lightOpacity: 0.12, dark: 0x9B8CFF, darkOpacity: 0.18)
    static let brandBorder = brand.opacity(0.34)
    static let inputFocusBorderWidth = 1.5
    static let primarySidebarSelection = brand
    static let projectDotPalette = [
        Color.billbiAdaptive(light: 0xFF5C7A, dark: 0xFF6F8D),
        Color.billbiAdaptive(light: 0xF97316, dark: 0xFB923C),
        Color.billbiAdaptive(light: 0xD9A30F, dark: 0xFACC15),
        Color.billbiAdaptive(light: 0x2F9E44, dark: 0x74C69D),
        Color.billbiAdaptive(light: 0x0EA5A4, dark: 0x5EEAD4),
        Color.billbiAdaptive(light: 0x0EA5E9, dark: 0x7DD3FC),
        Color.billbiAdaptive(light: 0x3B82F6, dark: 0x93C5FD),
        Color.billbiAdaptive(light: 0x6366F1, dark: 0xA5B4FC),
        Color.billbiAdaptive(light: 0x8B5CF6, dark: 0xC4B5FD),
        Color.billbiAdaptive(light: 0xA855F7, dark: 0xD8B4FE),
        Color.billbiAdaptive(light: 0xD946EF, dark: 0xF0ABFC),
        Color.billbiAdaptive(light: 0xEC4899, dark: 0xF9A8D4),
        Color.billbiAdaptive(light: 0xE11D48, dark: 0xFDA4AF),
        Color.billbiAdaptive(light: 0x14B8A6, dark: 0x99F6E4),
        Color.billbiAdaptive(light: 0x64748B, dark: 0xCBD5E1),
    ]

    static let success = Color.billbiAdaptive(light: 0x2F8F5A, dark: 0x7AC79A)
    static let successMuted = Color.billbiAdaptive(light: 0x2F8F5A, lightOpacity: 0.08, dark: 0x7AC79A, darkOpacity: 0.12)
    static let warning = Color.billbiAdaptive(light: 0xB57A1F, dark: 0xE0B26B)
    static let warningMuted = Color.billbiAdaptive(light: 0xB57A1F, lightOpacity: 0.08, dark: 0xE0B26B, darkOpacity: 0.12)
    static let danger = Color.billbiAdaptive(light: 0xC24545, dark: 0xE07B7B)
    static let dangerMuted = Color.billbiAdaptive(light: 0xC24545, lightOpacity: 0.08, dark: 0xE07B7B, darkOpacity: 0.12)
}

enum ProjectColorPalette {
    static let colors = BillbiColor.projectDotPalette

    static var colorCount: Int {
        colors.count
    }

    static func color(forProjectAt index: Int) -> Color {
        colors[colorIndex(forProjectAt: index)]
    }

    static func colorIndex(forProjectAt index: Int) -> Int {
        abs(index * 7) % colorCount
    }
}

private extension Color {
    static func billbiAdaptive(
        light: UInt,
        lightOpacity: Double = 1,
        dark: UInt,
        darkOpacity: Double = 1
    ) -> Color {
        #if os(macOS)
        Color(nsColor: .init(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor.billbiHex(isDark ? dark : light, opacity: isDark ? darkOpacity : lightOpacity)
        })
        #else
        Color(uiColor: .init { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.billbiHex(dark, opacity: darkOpacity)
                : UIColor.billbiHex(light, opacity: lightOpacity)
        })
        #endif
    }
}

#if os(macOS)
private extension NSColor {
    static func billbiHex(_ hex: UInt, opacity: Double) -> NSColor {
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
    static func billbiHex(_ hex: UInt, opacity: Double) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: opacity
        )
    }
}
#endif
