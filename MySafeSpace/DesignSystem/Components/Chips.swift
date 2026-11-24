import SwiftUI

/// Selectable capsule. Selected = violet fill + checkmark (not colour alone).
struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, Spacing.s + 2)
            .padding(.vertical, Spacing.xs)
            .frame(minHeight: minTapTarget)
            .foregroundStyle(isSelected ? Color.onBrandPrimary : Color.ink)
            .background(isSelected ? Color.brandPrimary : Color.surface, in: .capsule)
            .overlay(Capsule().strokeBorder(Color.ink.opacity(isSelected ? 0 : 0.14)))
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Read-only tag.
struct TagPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.inkSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.surfaceMuted, in: .capsule)
    }
}

/// Wrapping row layout for chips.
nonisolated struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width
            widest = max(widest, x)
            x += spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview("Chips") {
    FlowLayout {
        ForEach(Emotion.allCases) { emotion in
            Chip(title: emotion.label, isSelected: emotion == .calm || emotion == .anxious) {}
        }
        TagPill(title: "Sleep: Rested")
    }
    .padding()
    .screenBackground()
}
