import SwiftUI

/// Clinician photo on the role colour: psychiatrists on lemon (`brandSecondary`),
/// psychologists and psychotherapists on violet (`brandPrimary`).
/// Until real photos are added to the Asset Catalog (`photoAssetName`), it shows initials.
/// The role is always written next to it, so colour never carries meaning alone.
struct ClinicianPhoto: View {
    let clinician: Clinician?
    var size: CGFloat = 48
    /// A thin surface-coloured ring, for photos placed on coloured backgrounds (the Home hero).
    var ring = false

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if let name = clinician?.photoAssetName, UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(clinician?.initials ?? "?")
                    .font(.system(size: size * 0.32, weight: .bold))
                    .foregroundStyle(textColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay {
            if ring { Circle().strokeBorder(Color.surface, lineWidth: 3) }
        }
        .accessibilityHidden(true)
    }

    private var fill: Color {
        guard let role = clinician?.role else { return .surfaceMuted }
        switch role {
        case .psychiatrist: return .brandSecondary
        case .psychologist, .psychotherapist: return .brandPrimary
        case .reception: return .surfaceMuted
        }
    }

    private var textColor: Color {
        guard let role = clinician?.role else { return .ink }
        switch role {
        case .psychiatrist: return .onBrandSecondary
        case .psychologist, .psychotherapist: return .onBrandPrimary
        case .reception: return .ink
        }
    }
}

/// Stars + rating + opinion count, clearly labelled as coming from ZnanyLekarz.
/// MOCK: values are fixtures; no ZnanyLekarz API is connected yet.
struct ZnanyLekarzRating: View {
    let rating: Double
    let count: Int

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            StarsView(value: rating)
            Text(rating, format: .number.precision(.fractionLength(1)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ink)
            Text("\(count) opinions · from ZnanyLekarz")
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rated \(rating.formatted(.number.precision(.fractionLength(1)))) out of 5 from \(count) opinions on ZnanyLekarz"))
    }
}

struct StarsView: View {
    let value: Double

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: Double(index) <= value.rounded() ? "star.fill" : "star")
                    .font(.caption2)
            }
        }
        // Dark amber: 4.6:1 on white, so the stars stay visible for low vision.
        .foregroundStyle(Color(red: 0.62, green: 0.40, blue: 0.0))
        .accessibilityHidden(true)
    }
}

#Preview("Clinician photos") {
    HStack(spacing: 16) {
        ForEach(MockData.directory.clinicians) { ClinicianPhoto(clinician: $0, size: 56) }
    }
    .padding()
    .screenBackground()
}
