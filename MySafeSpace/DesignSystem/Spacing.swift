import SwiftUI

/// 4-pt grid.
nonisolated enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    /// Screen side margin.
    static let screen: CGFloat = 16
}

nonisolated enum Radius {
    static let card: CGFloat = 28
    static let inner: CGFloat = 20
    static let small: CGFloat = 14
}

/// Minimum tap target. DECISION: 48 pt everywhere (above the HIG's 44 pt), so every
/// control stays easy to hit on a hard day or with a shaky hand.
let minTapTarget: CGFloat = 48
