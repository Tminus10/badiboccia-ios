import SwiftUI

/// Marks a session on a test server (DEV or local), so nobody enters a result on the wrong
/// website: a thin line along the top of every screen and sheet (`.serverIndicatorLine()`) and a
/// tag next to the title (`ServerBadge`). Nothing is shown on the live site.
extension Theme {
    static let testServer = Color.orange
}

struct ServerBadge: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let badge = model.server.badge {
            Text(verbatim: badge)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.testServer, in: Capsule())
                .accessibilityLabel(model.server.title)
        }
    }
}

private struct ServerIndicatorLine: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if model.server.badge != nil {
                // A solid line with a glow fading down over the status bar: a bare thin line was easy to miss.
                VStack(spacing: 0) {
                    Theme.testServer
                        .frame(height: 6)
                    LinearGradient(colors: [Theme.testServer.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 44)
                }
                .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    func serverIndicatorLine() -> some View {
        modifier(ServerIndicatorLine())
    }
}
