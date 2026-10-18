import SwiftUI

/// A team's round badge -- its photo, or its pastel color with initials -- in the spot where the
/// Sports app shows a flag. A nil team (slot not decided yet) shows an empty dimmed circle.
struct TeamAvatar: View {
    let team: Team?
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            if let team {
                Circle().fill(Color(hex: team.colorHex))
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
                    .clipShape(Circle())
                }
            } else {
                Circle().fill(Color.white.opacity(0.08))
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
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
