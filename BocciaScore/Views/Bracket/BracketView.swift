import SwiftUI

/// The tournament tree, modeled on the Sports app's knockout view: a phase bar on top
/// (groups, quarter-finals, semi-finals, final) whose frame marks the visible columns, and
/// columns that snap horizontally -- group tables first, then each knockout round.
struct BracketView: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @State private var focusedColumn: Int? = 0
    /// Height of the bracket's scroll view without the tab bar, to center the knockout rounds in it.
    @State private var visibleHeight: CGFloat = 0
    /// The bracket's vertical scroll position, reset to the top when the knockout rounds get pinned.
    @State private var verticalPosition = ScrollPosition(edge: .top)

    @ScaledMetric(relativeTo: .caption) private var headerHeight: CGFloat = 28
    @ScaledMetric(relativeTo: .footnote) private var rowHeight: CGFloat = 38

    private let phases = BracketPhase.allCases
    private let horizontalInset: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let visible = BracketLayout.visibleColumns(forWidth: proxy.size.width, total: phases.count)
            // Never negative or infinite: the first layout pass can report a zero width, and there
            // are no phases before a season has loaded.
            let columnWidth = max((proxy.size.width - 2 * horizontalInset) / CGFloat(max(visible, 1)), 0)
            let layout = BracketLayout(columnWidth: columnWidth, headerHeight: headerHeight, rowHeight: rowHeight)
            let maxFocus = phases.count - visible
            let focus = min(focusedColumn ?? 0, maxFocus)

            VStack(spacing: 12) {
                header
                PhaseBar(phases: phases, focus: focus, visibleCount: visible) { index in
                    withAnimation(.snappy) { focusedColumn = min(index, maxFocus) }
                }
                .padding(.horizontal, horizontalInset)

                if let detail = model.selectedDetail {
                    let focusRound = max(focus - 1, 0)
                    // Knockout rounds are 0 (quarter-finals) to 2 (final); the phase bar counts the groups first.
                    let visibleRounds = (focus - 1)..<(focus + visible - 1)
                    let placement = knockoutPlacement(detail: detail, layout: layout, focusRound: focusRound,
                                                      visibleRounds: visibleRounds,
                                                      centerBlock: visible >= 3 || phases[focus] == .semiFinals)
                    // Pinned, the group column reaches past the bottom padding and the tab bar (or the
                    // home indicator) down to the edge of the display.
                    let groupsExtension = 24 + proxy.safeAreaInsets.bottom
                    ScrollView(.vertical) {
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 0) {
                                ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                                    column(phase, detail: detail, layout: layout, focusRound: focusRound, placement: placement,
                                           groupsExtension: groupsExtension)
                                        .frame(width: columnWidth, alignment: .topLeading)
                                        .id(index)
                                }
                            }
                            // Pinned, the bracket is exactly one screen high, whatever the rounds out of view need.
                            .frame(height: placement.isPinned ? availableHeight + groupsExtension : nil, alignment: .top)
                            .scrollTargetLayout()
                            .animation(.smooth(duration: 0.35), value: focus)
                        }
                        .contentMargins(.horizontal, horizontalInset, for: .scrollContent)
                        .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
                        .scrollPosition(id: $focusedColumn, anchor: .leading)
                        .scrollIndicators(.hidden)
                        .scrollDisabled(maxFocus == 0)
                        .padding(.bottom, 24)
                    }
                    // The scroll view already ends at the top of the tab bar; its bottom content inset is the
                    // tab bar again (content may scroll on behind it), so it doesn't count against the height.
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.containerSize.height - geometry.contentInsets.top
                    } action: { _, height in
                        visibleHeight = height
                    }
                    .scrollPosition($verticalPosition)
                    // Pinned, nothing moves vertically but the group column (which also takes pull to refresh).
                    .scrollDisabled(placement.isPinned)
                    // Pinned rounds sit in the middle of the screen: an offset left over from
                    // scrolling the bracket before (e.g. through the groups) would push them out of view.
                    .onChange(of: placement.isPinned) { _, isPinned in
                        if isPinned {
                            withAnimation(.smooth) { verticalPosition.scrollTo(edge: .top) }
                        }
                    }
                    .refreshable { await model.refresh() }
                } else {
                    SeasonLoadingState()
                    Spacer()
                }
            }
        }
        .themedScreen()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.qualifier.gradient)
                .padding(.top, 8)
            SeasonPicker()
            ArchivedSeasonNote()
        }
    }

    /// Where the knockout rounds sit vertically. All of them move down together, so the connector lines still meet.
    private struct KnockoutPlacement {
        var topInset: CGFloat
        /// Height of the leftmost visible knockout round (quarter- or semi-finals), the block the later rounds hang off.
        var blockHeight: CGFloat
        /// The knockout rounds fit on screen: they stay put in the vertical middle and only the group column scrolls.
        var isPinned: Bool
    }

    /// The bracket's height on screen, without the scroll view's bottom padding.
    private var availableHeight: CGFloat { visibleHeight - 24 }

    private func knockoutPlacement(detail: SeasonDetail, layout: BracketLayout, focusRound: Int,
                                   visibleRounds: Range<Int>, centerBlock: Bool) -> KnockoutPlacement {
        let championInset = detail.podium?.championId != nil
            ? layout.inset(aboveFinal: KnockoutColumn.championHeight, focusRound: focusRound) : 0
        let blockGames = focusRound == 0 ? detail.bracket.qf.count : detail.bracket.sf.count
        let blockHeight = layout.height(round: focusRound, count: blockGames, focusRound: focusRound)
        // Only the rounds in view count: on iPhone, the final (with the third-place game) is off to the
        // right next to the quarter-finals, and the quarter-finals are off to the left next to the final.
        let heights = [
            visibleRounds.contains(0) ? KnockoutColumn.height(round: 0, gameCount: detail.bracket.qf.count, layout: layout, focusRound: focusRound) : 0,
            visibleRounds.contains(1) ? KnockoutColumn.height(round: 1, gameCount: detail.bracket.sf.count, layout: layout, focusRound: focusRound) : 0,
            visibleRounds.contains(2) ? KnockoutColumn.height(round: 2, gameCount: detail.bracket.final == nil ? 0 : 1, layout: layout, focusRound: focusRound,
                                                              hasThirdPlace: detail.bracket.third != nil, thirdPlaceBottom: blockHeight) : 0,
        ]
        let contentHeight = heights.max() ?? 0
        // Centered between the phase bar and the tab bar.
        let centeredInset = (visibleHeight - blockHeight) / 2

        if visibleHeight > 0, championInset + contentHeight <= availableHeight {
            // Centered on the leftmost round, but never pushing the third-place game out of view.
            let inset = max(championInset, min(centeredInset, availableHeight - contentHeight))
            return KnockoutPlacement(topInset: inset, blockHeight: blockHeight, isPinned: true)
        }
        // Too tall: everything scrolls together. The block is still centered where there's room
        // (iPad, and iPhone with only the semi-finals and the final in view).
        let inset = max(championInset, centerBlock ? centeredInset : 0)
        return KnockoutPlacement(topInset: inset, blockHeight: blockHeight, isPinned: false)
    }

    @ViewBuilder
    private func column(_ phase: BracketPhase, detail: SeasonDetail, layout: BracketLayout, focusRound: Int,
                        placement: KnockoutPlacement, groupsExtension: CGFloat) -> some View {
        let topInset = placement.topInset
        switch phase {
        case .groups:
            // No connector lines leave the group column, so it only needs a small gap.
            let groups = GroupStageColumn(detail: detail, width: max(layout.columnWidth - 10, 0))
            if placement.isPinned {
                // The knockout rounds stay put; the group tables scroll on their own, down to the edge of
                // the display behind the tab bar, and the last group can still scroll up above it.
                ScrollView(.vertical) { groups }
                    .scrollIndicators(.hidden)
                    .contentMargins(.bottom, groupsExtension, for: .scrollContent)
                    .frame(height: availableHeight + groupsExtension)
            } else {
                groups
            }
        case .quarterFinals:
            KnockoutColumn(round: 0, games: detail.bracket.qf, detail: detail, layout: layout, focusRound: focusRound, topInset: topInset)
        case .semiFinals:
            KnockoutColumn(round: 1, games: detail.bracket.sf, detail: detail, layout: layout, focusRound: focusRound, topInset: topInset)
        case .final:
            KnockoutColumn(round: 2, games: detail.bracket.final.map { [$0] } ?? [], detail: detail, layout: layout,
                           focusRound: focusRound, topInset: topInset, thirdPlace: detail.bracket.third,
                           // Pinned: down at the bottom of the screen, like on the website.
                           thirdPlaceBottom: placement.isPinned ? availableHeight - topInset : placement.blockHeight)
        }
    }
}

enum BracketPhase: Int, CaseIterable, Hashable {
    case groups, quarterFinals, semiFinals, final

    /// Short label above the phase bar icons.
    var abbreviation: String {
        switch self {
        case .groups: String(localized: "GP", comment: "Phase bar: group phase")
        case .quarterFinals: String(localized: "VF", comment: "Phase bar: quarter-finals")
        case .semiFinals: String(localized: "HF", comment: "Phase bar: semi-finals")
        case .final: String(localized: "F", comment: "Phase bar: final")
        }
    }

    var title: String {
        switch self {
        case .groups: Phase.group.title
        case .quarterFinals: Phase.qf.title
        case .semiFinals: Phase.sf.title
        case .final: Phase.final.title
        }
    }
}

// MARK: - Group stage column

/// Compact group tables (rank, team, points) as the tree's first column.
private struct GroupStageColumn: View {
    let detail: SeasonDetail
    let width: CGFloat

    var body: some View {
        let teams = detail.teamsByID
        let started = detail.groupPhaseStarted
        VStack(spacing: 14) {
            ForEach(detail.groups) { group in
                VStack(spacing: 0) {
                    HStack {
                        CardHeading(text: String(localized: "Gruppe \(group.name)"))
                        Spacer()
                        CardHeading(text: String(localized: "PKT", comment: "Abbreviation: points"))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Theme.cardHeader)
                    Divider().overlay(Theme.separator)

                    ForEach(group.standings, id: \.teamId) { row in
                        NavigationLink(value: Route.team(id: row.teamId, seasonID: detail.season.id)) {
                            HStack(spacing: 7) {
                                Text("\(row.rank)")
                                    .font(.footnote.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(started && row.rank <= detail.qualifiersPerGroup ? Theme.qualifier : Theme.secondaryText)
                                    .frame(width: 14)
                                Circle()
                                    .fill(Color(hex: teams[row.teamId]?.colorHex ?? ""))
                                    .frame(width: 8, height: 8)
                                Text(teams[row.teamId]?.name ?? "–")
                                    .font(.footnote)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(row.points)")
                                    .font(.footnote.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 10)
                            .frame(minHeight: 40)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .card(cornerRadius: 14)
            }
        }
        .frame(width: width)
    }
}

// MARK: - Knockout column

/// One knockout round, with the bracket lines leading to the next round.
private struct KnockoutColumn: View {
    let round: Int
    let games: [Game]
    let detail: SeasonDetail
    let layout: BracketLayout
    let focusRound: Int
    var topInset: CGFloat = 0
    var thirdPlace: Game? = nil
    /// Where the third-place game's bottom edge goes when there's room below the final: the bottom of
    /// the screen when the knockout rounds are pinned, else the bottom of the leftmost visible round.
    var thirdPlaceBottom: CGFloat = 0

    /// Room for the champion badge above the final, including the gap to the card.
    static let championHeight: CGFloat = 110

    private let line = Color.white.opacity(0.28)

    var body: some View {
        ZStack(alignment: .topLeading) {
            if games.isEmpty {
                Text("Noch nicht festgelegt")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: layout.cardWidth, height: layout.cardHeight)
                    .card(cornerRadius: 14)
            }
            if round < 2 {
                connectors
                    .opacity(round < focusRound ? 0 : 1)
            }
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                BracketGameCard(game: game, detail: detail, layout: layout)
                    .offset(y: layout.topY(round: round, index: index, focusRound: focusRound))
            }
            if round == 2, let championID = detail.podium?.championId, let champion = detail.teamsByID[championID] {
                ChampionBadge(team: champion, seasonID: detail.season.id)
                    .frame(width: layout.cardWidth, height: Self.championHeight - 14, alignment: .bottom)
                    .offset(y: layout.topY(round: round, index: 0, focusRound: focusRound) - Self.championHeight)
            }
            if let thirdPlace {
                thirdPlaceSection(thirdPlace)
            }
        }
        .frame(width: layout.columnWidth, height: height, alignment: .topLeading)
        .padding(.top, topInset)
    }

    /// Space between the final and the third-place game, so the champion and the final read as one block.
    private static let thirdPlaceGap: CGFloat = 32

    /// The third-place game's label and card.
    private static func thirdPlaceHeight(_ layout: BracketLayout) -> CGFloat { 32 + layout.cardHeight }

    /// At `bottom` when there's room, else just below the final.
    private static func thirdPlaceTop(finalBottom: CGFloat, bottom: CGFloat, layout: BracketLayout) -> CGFloat {
        max(finalBottom + thirdPlaceGap, bottom - thirdPlaceHeight(layout))
    }

    /// The column's height without the top inset; BracketView uses it to tell whether the knockout rounds fit on screen.
    static func height(round: Int, gameCount: Int, layout: BracketLayout, focusRound: Int,
                       hasThirdPlace: Bool = false, thirdPlaceBottom: CGFloat = 0) -> CGFloat {
        let finalBottom = layout.height(round: round, count: gameCount, focusRound: focusRound)
        guard hasThirdPlace else { return finalBottom }
        return thirdPlaceTop(finalBottom: finalBottom, bottom: thirdPlaceBottom, layout: layout) + thirdPlaceHeight(layout)
    }

    private var finalBottom: CGFloat {
        layout.height(round: round, count: games.count, focusRound: focusRound)
    }

    private var thirdPlaceTop: CGFloat {
        Self.thirdPlaceTop(finalBottom: finalBottom, bottom: thirdPlaceBottom, layout: layout)
    }

    private var height: CGFloat {
        Self.height(round: round, gameCount: games.count, layout: layout, focusRound: focusRound,
                    hasThirdPlace: thirdPlace != nil, thirdPlaceBottom: thirdPlaceBottom)
    }

    /// "⊐" shapes joining each pair of games, plus the stub into the next round's game.
    /// Plain rectangles rather than a Path, so they animate in step with the cards when the layout re-packs.
    @ViewBuilder
    private var connectors: some View {
        let mid = layout.cardWidth + layout.connectorGap / 2
        ForEach(0..<(games.count / 2), id: \.self) { pair in
            let y1 = layout.centerY(round: round, index: 2 * pair, focusRound: focusRound)
            let y2 = layout.centerY(round: round, index: 2 * pair + 1, focusRound: focusRound)
            let yNext = layout.centerY(round: round + 1, index: pair, focusRound: focusRound)
            let top = min(y1, y2, yNext), bottom = max(y1, y2, yNext)
            Group {
                line.frame(width: layout.connectorGap / 2, height: 1).offset(x: layout.cardWidth, y: y1)
                line.frame(width: layout.connectorGap / 2, height: 1).offset(x: layout.cardWidth, y: y2)
                line.frame(width: 1, height: bottom - top + 1).offset(x: mid, y: top)
                line.frame(width: layout.connectorGap / 2, height: 1).offset(x: mid, y: yNext)
            }
        }
    }

    private func thirdPlaceSection(_ game: Game) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // The card's header names the game itself until it has a date.
            Text(game.dateLabel != nil ? Phase.third.title : " ")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .frame(height: 24, alignment: .bottom)
            BracketGameCard(game: game, detail: detail, layout: layout)
        }
        .offset(y: thirdPlaceTop)
    }
}

/// The trophy and the winning team, above the final.
private struct ChampionBadge: View {
    let team: Team
    let seasonID: Int

    var body: some View {
        NavigationLink(value: Route.team(id: team.id, seasonID: seasonID)) {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    TeamAvatar(team: team, size: 48)
                    Image(systemName: "trophy.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.qualifier, Theme.backgroundBottom)
                        .offset(x: 8, y: 4)
                }
                Text(team.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Turniersieger")
                    .font(.caption)
                    .foregroundStyle(Theme.qualifier)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Game card

/// A bracket game: date (or round name) on top, then both teams with their sets; the loser is dimmed.
struct BracketGameCard: View {
    let game: Game
    let detail: SeasonDetail
    let layout: BracketLayout
    @Environment(Navigator.self) private var navigator

    var body: some View {
        let teams = detail.teamsByID
        Button {
            navigator.open(game)
        } label: {
            VStack(spacing: 0) {
                Text(game.dateLabel ?? game.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: layout.headerHeight, maxHeight: layout.headerHeight, alignment: .leading)
                    .background(Theme.cardHeader)
                row(team: game.teamAId.flatMap { teams[$0] }, sets: game.setsA, placeholder: game.placeholderA)
                Divider().overlay(Theme.separator)
                row(team: game.teamBId.flatMap { teams[$0] }, sets: game.setsB, placeholder: game.placeholderB)
            }
            .frame(width: layout.cardWidth, height: layout.cardHeight)
            .card(cornerRadius: 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Zeigt Details zum Spiel"))
    }

    private func row(team: Team?, sets: Int?, placeholder: Placeholder?) -> some View {
        let isWinner = team != nil && game.winnerTeamId == team?.id
        let isLoser = team != nil && game.winnerTeamId != nil && !isWinner
        return HStack(spacing: 8) {
            TeamLabel(team: team, placeholder: placeholder, avatarSize: 20, emphasized: isWinner, dimmed: isLoser)
                .font(.footnote)
            Spacer(minLength: 4)
            if let sets {
                Text("\(sets)")
                    .font(.footnote.monospacedDigit().weight(.bold))
                    .foregroundStyle(isLoser ? Theme.secondaryText : .white)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: layout.rowHeight)
    }
}

// MARK: - Phase bar

/// Sports-app phase selector: labels above simple glyphs, and a white frame around the
/// phases currently visible below. Tapping a phase scrolls the tree there.
struct PhaseBar: View {
    let phases: [BracketPhase]
    let focus: Int
    let visibleCount: Int
    let select: (Int) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                    Text(phase.abbreviation)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isVisible(index) ? .white : Theme.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            GeometryReader { proxy in
                let itemWidth = proxy.size.width / CGFloat(max(phases.count, 1))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.07))
                    selectionFrame
                        .frame(width: itemWidth * CGFloat(visibleCount))
                        .offset(x: itemWidth * CGFloat(focus))
                        .animation(.snappy, value: focus)
                    HStack(spacing: 0) {
                        ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                            Button {
                                select(index)
                            } label: {
                                PhaseGlyph(phase: phase)
                                    .foregroundStyle(isVisible(index) ? .white : Theme.tertiaryText)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(phase.title))
                            .accessibilityAddTraits(isVisible(index) ? .isSelected : [])
                        }
                    }
                }
            }
            .frame(height: 56)
        }
    }

    private func isVisible(_ index: Int) -> Bool {
        index >= focus && index < focus + visibleCount
    }

    private var selectionFrame: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.1))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white, lineWidth: 3)
            }
            .overlay {
                HStack {
                    Image(systemName: "chevron.compact.left")
                    Spacer()
                    Image(systemName: "chevron.compact.right")
                }
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
            }
    }
}

/// The little pictograms of the phase bar: many lines for early rounds, fewer later, a trophy for the final.
private struct PhaseGlyph: View {
    let phase: BracketPhase

    var body: some View {
        switch phase {
        case .groups:
            lines(count: 4, thickness: 4, spacing: 3)
        case .quarterFinals:
            lines(count: 4, thickness: 1.5, spacing: 5)
        case .semiFinals:
            lines(count: 2, thickness: 1.5, spacing: 8)
        case .final:
            Image(systemName: "trophy")
                .font(.system(size: 20, weight: .regular))
        }
    }

    private func lines(count: Int, thickness: CGFloat, spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { _ in
                Capsule().frame(width: 30, height: thickness)
            }
        }
    }
}
