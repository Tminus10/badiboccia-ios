import SwiftUI

/// Marks a session that isn't the real league -- a test server (DEV or local) or a logged-in
/// demo team -- so nobody enters a result in the wrong place: a line along the top of every
/// screen and sheet (`.serverIndicatorLine()`) and a tag next to the title (`ServerBadge`).
/// Nothing is shown for a real team on the live site.
extension Theme {
    static let testServer = Color.orange
    static let demo = Color(red: 0.38, green: 0.86, blue: 0.66)
}

private extension AppModel {
    /// The demo marker; the `-hideDemoMarker` launch argument hides it for App Store screenshots.
    var showsDemoMarker: Bool {
        guard isDemoSession else { return false }
        #if DEBUG
        return !UserDefaults.standard.bool(forKey: "hideDemoMarker")
        #else
        return true
        #endif
    }

    /// The test server wins over the demo: which website you're on matters more.
    var indicatorColor: Color? {
        if server.badge != nil { return Theme.testServer }
        return showsDemoMarker ? Theme.demo : nil
    }
}

struct ServerBadge: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 6) {
            if let badge = model.server.badge {
                tag(badge, color: Theme.testServer)
                    .accessibilityLabel(model.server.title)
            }
            if model.showsDemoMarker {
                tag("DEMO", color: Theme.demo)
                    .accessibilityLabel(Text("Demo-Modus"))
            }
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(verbatim: text)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}

private struct ServerIndicatorLine: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let color = model.indicatorColor {
                // A solid line with a glow fading down over the status bar: a bare thin line was easy to miss.
                VStack(spacing: 0) {
                    color
                        .frame(height: 6)
                    LinearGradient(colors: [color.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
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
