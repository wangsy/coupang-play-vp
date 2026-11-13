import SwiftUI
import UIKit

@main
struct CoupangPlayVPApp: App {
    /// One browser for the window and the cinema space (cinema spec C2), created lazily — see `BrowserHolder`.
    @State private var holder = BrowserHolder()
    @State private var cinemaStyle: any ImmersionStyle = .progressive(0.0...1.0, initialAmount: 1.0)

    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "?") (\(info["CFBundleVersion"] ?? "?"))"
        let device = UIDevice.current
        EventLog.shared.log(.app, "launch \(version) \(device.systemName) \(device.systemVersion) \(device.model)")
    }

    var body: some Scene {
        WindowGroup(id: "browser") {
            ContentView(model: holder.model)
        }
        .defaultSize(width: 1280, height: 800) // wide enough for the desktop layout (spec S1)

        ImmersiveSpace(id: CinemaSpace.id) {
            CinemaSpace(model: holder.model)
        }
        .immersionStyle(selection: $cinemaStyle, in: .progressive(0.0...1.0, initialAmount: 1.0))
    }
}

/// Creates the browser on first use from a scene's content, not in `App.init`.
/// `App.init` runs before `UIApplicationMain`; a `WKWebView` made there crashed UIKit's gesture handling on the
/// first touch (`-[UIGestureRecognizer _delayTouchesForEvent:inPhase:]` inserting nil, 2026-11-13 device crash reports).
@MainActor
final class BrowserHolder {
    private(set) lazy var model = BrowserModel(startURL: SiteConfig.startURL)
}

extension CinemaSpace {
    static let id = "cinema"
}
