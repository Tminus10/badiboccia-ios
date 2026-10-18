import CoreGraphics

/// Geometry of the tournament tree, Sports-app style: the leftmost visible knockout round is
/// packed tightly, and every later round centers each game between the two games feeding it.
/// Scrolling to a later round re-packs from there, so the bracket never wastes vertical space.
struct BracketLayout: Equatable {
    /// Width of one column, including the gap on its right where the connector lines run.
    var columnWidth: CGFloat
    var connectorGap: CGFloat = 18
    var headerHeight: CGFloat
    var rowHeight: CGFloat
    var spacing: CGFloat = 14

    var cardWidth: CGFloat { columnWidth - connectorGap }
    /// Date header + two team rows + the hairline between them.
    var cardHeight: CGFloat { headerHeight + 2 * rowHeight + 1 }
    var unit: CGFloat { cardHeight + spacing }

    /// Vertical distance between two neighboring games of `round` (0 = QF, 1 = SF, 2 = final)
    /// when `focusRound` is the leftmost visible knockout round.
    func step(round: Int, focusRound: Int) -> CGFloat {
        unit * CGFloat(1 << max(round - focusRound, 0))
    }

    /// Center y of game `index` in `round`.
    func centerY(round: Int, index: Int, focusRound: Int) -> CGFloat {
        let step = step(round: round, focusRound: focusRound)
        return cardHeight / 2 + (step - unit) / 2 + CGFloat(index) * step
    }

    func topY(round: Int, index: Int, focusRound: Int) -> CGFloat {
        centerY(round: round, index: index, focusRound: focusRound) - cardHeight / 2
    }

    /// Height taken by `count` games of `round`.
    func height(round: Int, count: Int, focusRound: Int) -> CGFloat {
        guard count > 0 else { return cardHeight }
        return centerY(round: round, index: count - 1, focusRound: focusRound) + cardHeight / 2
    }

    /// Extra space the knockout columns need on top so a block of `height` (the champion badge)
    /// fits above the final; zero when the gap above the final is already big enough.
    func inset(aboveFinal height: CGFloat, focusRound: Int) -> CGFloat {
        max(height - topY(round: 2, index: 0, focusRound: focusRound), 0)
    }

    /// How many columns fit side by side: two on iPhone, like the Sports app; more on iPad.
    static func visibleColumns(forWidth width: CGFloat, total: Int) -> Int {
        let fitting = width >= 1000 ? 4 : (width >= 680 ? 3 : 2)
        return min(fitting, total)
    }
}
