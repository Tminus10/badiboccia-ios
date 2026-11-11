import SwiftUI

/// A team's photo shown large, opened by tapping the avatar on its team page (like the website).
/// Tapping anywhere or the close button dismisses it.
struct TeamPhotoView: View {
    let team: Team

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let url = team.photoUrl {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else if phase.error == nil {
                        ProgressView().controlSize(.large)
                    } else {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .frame(maxWidth: 500, maxHeight: 500)
                .clipShape(.rect(cornerRadius: 40, style: .continuous))
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Button(role: .close) {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Schliessen"))
            .padding()
        }
        .contentShape(.rect)
        .onTapGesture { dismiss() }
        .accessibilityLabel(Text(team.name))
    }
}
