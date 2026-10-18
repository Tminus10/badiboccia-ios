import SwiftUI

/// A group's table as in the Sports app: Team, games played, won, drawn, lost, set difference, points.
/// The teams that go through to the quarter-finals are marked once the group phase has started.
struct StandingsCard: View {
    let group: TeamGroup
    let detail: SeasonDetail

    var body: some View {
        let teams = detail.teamsByID
        let showQualifiers = group.games.contains(where: \.isComplete)
        let showDraws = group.standings.contains { $0.tied > 0 }
        VStack(spacing: 10) {
            Text("Gruppe \(group.name)")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top, 16)
                .accessibilityAddTraits(.isHeader)

            if group.standings.isEmpty {
                EmptyStateText(text: String(localized: "Noch keine Teams."))
            } else {
                Grid(alignment: .trailing, horizontalSpacing: 4, verticalSpacing: 0) {
                    GridRow {
                        Text("Team").gridColumnAlignment(.leading)
                        Text("SP", comment: "Abbreviation: games played")
                        Text("S", comment: "Abbreviation: won")
                        if showDraws {
                            Text("U", comment: "Abbreviation: drawn")
                        }
                        Text("N", comment: "Abbreviation: lost")
                        Text("SD", comment: "Abbreviation: set difference")
                        Text("PKT", comment: "Abbreviation: points")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.bottom, 6)
                    .accessibilityHidden(true)

                    ForEach(group.standings, id: \.teamId) { row in
                        let team = teams[row.teamId]
                        let qualifies = showQualifiers && row.rank <= detail.qualifiersPerGroup
                        GridRow {
                            NavigationLink(value: Route.team(id: row.teamId, seasonID: detail.season.id)) {
                                HStack(spacing: 8) {
                                    Capsule()
                                        .fill(qualifies ? Theme.qualifier : .clear)
                                        .frame(width: 3, height: 22)
                                    TeamAvatar(team: team, size: 24)
                                    Text(team?.name ?? "–")
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            stat(row.played)
                            stat(row.won)
                            if showDraws {
                                stat(row.tied)
                            }
                            stat(row.lost)
                            Text(row.setDifference > 0 ? "+\(row.setDifference)" : "\(row.setDifference)")
                                .frame(minWidth: 30, alignment: .trailing)
                            Text("\(row.points)")
                                .fontWeight(.semibold)
                                .frame(minWidth: 34, alignment: .trailing)
                        }
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.vertical, 9)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(accessibilityText(row, team: team, qualifies: qualifies))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private func stat(_ value: Int) -> some View {
        Text("\(value)").frame(minWidth: 24, alignment: .trailing)
    }

    private func accessibilityText(_ row: StandingRow, team: Team?, qualifies: Bool) -> String {
        var text = String(localized: "Rang \(row.rank), \(team?.name ?? ""), \(row.points) Punkte, \(row.won) Siege, \(row.lost) Niederlagen")
        if qualifies { text += ", " + String(localized: "qualifiziert") }
        return text
    }
}
