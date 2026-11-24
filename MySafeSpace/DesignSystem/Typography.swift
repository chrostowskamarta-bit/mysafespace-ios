import SwiftUI

/// Semantic text styles only, so Dynamic Type scales everything.
/// DECISION: every text uses the iPhone system font, SF Pro (no rounded variant, no custom fonts).
extension Font {
    static let displayTitle = Font.system(.largeTitle, weight: .bold)
    static let screenTitle = Font.system(.title, weight: .bold)
    static let sectionTitle = Font.system(.title3, weight: .semibold)
    static let cardTitle = Font.system(.headline, weight: .semibold)
}

extension View {
    /// Standard secondary text treatment.
    func secondaryText() -> some View {
        self.font(.subheadline).foregroundStyle(Color.inkSecondary)
    }
}
