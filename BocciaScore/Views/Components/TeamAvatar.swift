import SwiftUI

/// A team's badge -- its photo, or its pastel color with initials -- in the spot where the
/// Sports app shows a flag, shaped as a squircle like an app icon. A nil team (slot not decided
/// yet) shows an empty dimmed squircle.
struct TeamAvatar: View {
    let team: Team?
    var size: CGFloat = 28

    /// Continuous rounded corners at the app-icon ratio; the website's .avatar matches it.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
    }

    var body: some View {
        ZStack {
            if let team {
                shape.fill(Color(hex: team.colorHex))
                Text(team.initials)
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.72))
                    .minimumScaleFactor(0.5)
                if let url = team.photoUrl {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        }
                    }
                    .clipShape(shape)
                }
            } else {
                shape.fill(Color.white.opacity(0.08))
            }
        }
        .frame(width: size, height: size)
        .overlay {
            // A border in the team's color, like on the website.
            if let team {
                shape.strokeBorder(Color(hex: team.colorHex), lineWidth: max(1.5, size / 32))
            } else {
                shape.strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Avatar plus name, or the placeholder text ("Sieger Gruppe A") for an undecided slot.
struct TeamLabel: View {
    let team: Team?
    var placeholder: Placeholder? = nil
    var avatarSize: CGFloat = 24
    var emphasized = false
    var dimmed = false

    var body: some View {
        HStack(spacing: 10) {
            TeamAvatar(team: team, size: avatarSize)
            Text(team?.name ?? placeholder?.label ?? "–")
                .fontWeight(emphasized ? .semibold : .regular)
                .foregroundStyle(team == nil || dimmed ? Theme.secondaryText : .white)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
