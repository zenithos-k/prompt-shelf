import AppKit
import SwiftUI

enum PreferenceKey {
    static let appearanceMode = "appearanceMode"
    static let closeAfterCopy = "closeAfterCopy"
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

}

@MainActor
enum AppAppearanceController {
    static func apply(_ mode: AppearanceMode) {
        let appearance: NSAppearance?

        switch mode {
        case .system:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        }

        // Apply the preference only to the open shelf window. Setting
        // `NSApp.appearance` also recolors the NSStatusItem in the menu bar,
        // making the icon change when users toggle the shelf appearance.
        NSApp.keyWindow?.appearance = appearance
        NSApp.keyWindow?.contentView?.needsDisplay = true
    }
}
