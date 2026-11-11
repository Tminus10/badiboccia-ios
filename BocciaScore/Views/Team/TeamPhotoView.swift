import SwiftUI

/// A team's photo shown large, opened by tapping the avatar on its team page. Like the website:
/// the team page stays visible but dimmed behind it, the photo is at most 500 × 500 pt (the size
/// photos are stored at) with squircle corners, and a tap anywhere closes it.
struct TeamPhotoView: View {
    let team: Team

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Same dimming as the website's .photo-dialog::backdrop.
            Color(red: 10 / 255, green: 20 / 255, blue: 15 / 255, opacity: 0.75)
                .ignoresSafeArea()

            if let url = team.photoUrl {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                            .clipShape(Squircle())
                            // A thin border in the team's color, like the avatar's.
                            .overlay { Squircle().strokeBorder(Color(hex: team.colorHex), lineWidth: 3) }
                            .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
                    } else if phase.error == nil {
                        ProgressView().controlSize(.large)
                    } else {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .frame(maxWidth: 500, maxHeight: 500)
                .padding(24)
            }
        }
        .contentShape(.rect)
        .onTapGesture { dismiss() }
        .presentationBackground(.clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(team.name))
        .accessibilityAddTraits(.isImage)
        .accessibilityAction(.escape) { dismiss() }
        .accessibilityAction(named: Text("Schliessen")) { dismiss() }
    }
}

/// Continuous corners at the app-icon ratio of whatever size the shape gets, like TeamAvatar.
private struct Squircle: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        return RoundedRectangle(cornerRadius: min(rect.width, rect.height) * 0.225, style: .continuous)
            .path(in: rect)
    }

    func inset(by amount: CGFloat) -> Squircle {
        Squircle(inset: inset + amount)
    }
}
