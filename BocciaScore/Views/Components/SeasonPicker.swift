import SwiftUI

/// The glass capsule with the tournament name, like "FIFA World Cup 2026" in the Sports app;
/// opens a menu of every season, so past seasons (the website's archive) are one tap away.
struct SeasonPicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Menu {
            Picker("Saison", selection: $model.selectedSeasonID) {
                ForEach(model.seasons) { season in
                    Group {
                        if season.isCurrent {
                            Label(season.label, systemImage: "star.fill")
                        } else {
                            Text(season.label)
                        }
                    }
                    .tag(Optional(season.id))
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Theme.qualifier)
                Text(model.selectedSeason?.label ?? String(localized: "Saison"))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular.tint(Theme.backgroundTop.opacity(0.5)).interactive(), in: .capsule)
        }
        .accessibilityLabel(Text("Saison wählen"))
        .accessibilityValue(Text(model.selectedSeason?.label ?? ""))
    }
}

/// Banner for archived seasons: they're read-only, like on the website.
struct ArchivedSeasonNote: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let season = model.selectedSeason, !season.isCurrent {
            Label("Archiv – diese Saison ist abgeschlossen", systemImage: "archivebox")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity)
        }
    }
}

/// Error or loading state for a screen whose season data isn't there yet.
struct SeasonLoadingState: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 16) {
            if let error = model.lastError {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.secondaryText)
                Text(error.localizedDescription)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText)
                Button("Erneut versuchen") {
                    Task { await model.refresh() }
                }
                .buttonStyle(.glass)
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}
