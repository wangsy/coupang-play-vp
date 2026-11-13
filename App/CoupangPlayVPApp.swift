import SwiftUI
import UIKit

@main
struct CoupangPlayVPApp: App {
    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "?") (\(info["CFBundleVersion"] ?? "?"))"
        let device = UIDevice.current
        EventLog.shared.log(.app, "launch \(version) \(device.systemName) \(device.systemVersion) \(device.model)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1280, height: 800) // wide enough for the desktop layout (spec S1)
    }
}
