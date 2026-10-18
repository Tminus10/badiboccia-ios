import SwiftUI

/// The home screen, modeled on the Sports app's tournament page: title and season capsule,
/// a scoreboard card (recent / today / upcoming), then one standings card per group.
struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                ArchivedSeasonNote()
                if let detail = model.selectedDetail {
                    if let podium = detail.podium {
                        PodiumCard(podium: podium, detail: detail)
                    }
                    ScoreboardCard(detail: detail)
                    standings(detail)
                } else {
                    SeasonLoadingState()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .themedScreen()
        .refreshable { await model.refresh() }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                title
                Spacer(minLength: 12)
                SeasonPicker()
            }
            VStack(alignment: .leading, spacing: 12) {
                title
                SeasonPicker()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 8)
    }

    private var title: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.hexagongrid.fill")
                .foregroundStyle(Theme.qualifier)
            Text("Boccia")
        }
        .font(.system(size: 38, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func standings(_ detail: SeasonDetail) -> some View {
        let columns = sizeClass == .regular
            ? [GridItem(.flexible(), spacing: 16, alignment: .top), GridItem(.flexible(), spacing: 16, alignment: .top)]
            : [GridItem(.flexible(), alignment: .top)]
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(detail.groups) { group in
                StandingsCard(group: group, detail: detail)
            }
        }
    }
}

// MARK: - Podium

/// Shown once the final is decided: the season's top three.
struct PodiumCard: View {
    let podium: Podium
    let detail: SeasonDetail

    var body: some View {
        let teams = detail.teamsByID
        VStack(spacing: 14) {
            Text("Rangliste")
                .font(.headline)
                .foregroundStyle(.white)
            HStack(alignment: .bottom, spacing: 12) {
                place(2, team: podium.runnerUpId.flatMap { teams[$0] }, medal: "🥈", height: 64)
                place(1, team: podium.championId.flatMap { teams[$0] }, medal: "🥇", height: 84)
                place(3, team: podium.thirdId.flatMap { teams[$0] }, medal: "🥉", height: 48)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .card()
        .accessibilityElement(children: .combine)
    }

    private func place(_ rank: Int, team: Team?, medal: String, height: CGFloat) -> some View {
        NavigationLink(value: team.map { Route.team(id: $0.id, seasonID: detail.season.id) }) {
            VStack(spacing: 6) {
                TeamAvatar(team: team, size: rank == 1 ? 56 : 44)
                Text(team?.name ?? String(localized: "offen"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(team == nil ? Theme.secondaryText : .white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 32, alignment: .top)
                Text(medal)
                    .font(.system(size: 34))
                    .frame(maxWidth: .infinity, minHeight: height)
                    .background(Color.white.opacity(rank == 1 ? 0.14 : 0.08), in: .rect(cornerRadius: 10))
            }
        }
        .buttonStyle(.plain)
        .disabled(team == nil)
        .frame(maxWidth: .infinity)
    }
}
