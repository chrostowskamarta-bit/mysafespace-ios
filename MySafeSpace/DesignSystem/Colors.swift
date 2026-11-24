import SwiftUI

/// Design tokens backed by Asset Catalog colour sets (light + dark variants).
/// Contrast was checked for every text/background pair — see README "Accessibility".
///
/// DECISION: Swift asset-symbol generation is off so token names can't clash with
/// SwiftUI's own `ShapeStyle.background`. Always spell these as `Color.ink`, not `.ink`,
/// when the expected type is a generic `ShapeStyle`.
extension Color {
    /// Violet. Primary buttons, links, selected states. 5.3:1 with white text.
    nonisolated static let brandPrimary = Color("brandPrimary")
    /// Darker violet for small violet text on light surfaces (6.7:1).
    nonisolated static let brandPrimaryStrong = Color("brandPrimaryStrong")
    /// Lemon green. FILLS AND HIGHLIGHTS ONLY — never as text or icon colour on light surfaces.
    nonisolated static let brandSecondary = Color("brandSecondary")
    /// Text/icons drawn on `brandPrimary` (white in light mode, deep ink in dark mode).
    nonisolated static let onBrandPrimary = Color("onBrandPrimary")
    /// Text/icons drawn on `brandSecondary` (always ink).
    nonisolated static let onBrandSecondary = Color("onBrandSecondary")

    nonisolated static let ink = Color("ink")
    nonisolated static let inkSecondary = Color("inkSecondary")
    nonisolated static let appBackground = Color("background")
    nonisolated static let surface = Color("surface")
    nonisolated static let surfaceMuted = Color("surfaceMuted")

    /// Calm, neutral background for the crisis screen (no lemon, no characters).
    nonisolated static let crisisBackground = Color("crisisBackground")
    /// Dark backdrop for the mock video call.
    nonisolated static let callBackground = Color("callBackground")

    /// Facial features on mood characters (always dark, all mood fills are light enough).
    nonisolated static let moodInk = Color("moodInk")
    nonisolated static let mood1 = Color("mood1")
    nonisolated static let mood2 = Color("mood2")
    nonisolated static let mood3 = Color("mood3")
    nonisolated static let mood4 = Color("mood4")
    nonisolated static let mood5 = Color("mood5")
}

extension MoodLevel {
    /// Soft, desaturated scale. Meaning is never carried by colour alone — every use pairs
    /// the colour with a face and a text label.
    var color: Color {
        switch self {
        case .veryLow: .mood1
        case .low: .mood2
        case .okay: .mood3
        case .good: .mood4
        case .great: .mood5
        }
    }
}
