import UIKit
import WebKit

/// Saves what the web view shows at interesting moments, next to `events.log` (spec S9).
/// DRM video frames come out black — that is the system protecting them, not a bug.
@MainActor
final class Snapshotter {
    private weak var webView: WKWebView?
    private var count = 0
    private var lastShot = Date.distantPast
    private var pending: Task<Void, Never>?
    private static let minimumGap: TimeInterval = 1

    init(webView: WKWebView) {
        self.webView = webView
    }

    /// Takes a snapshot after `delay` seconds. A newer request replaces one still waiting.
    func capture(_ reason: String, after delay: Double = 0.8) {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.shoot(reason)
        }
    }

    private func shoot(_ reason: String) async {
        guard let webView, webView.bounds.width > 0, Date().timeIntervalSince(lastShot) >= Self.minimumGap else { return }
        lastShot = Date()
        let configuration = WKSnapshotConfiguration()
        configuration.afterScreenUpdates = true
        guard let image = try? await webView.takeSnapshot(configuration: configuration),
              let data = image.jpegData(compressionQuality: 0.6) else {
            EventLog.shared.log(.snap, "failed (\(reason))")
            return
        }
        count += 1
        let safe = reason.replacingOccurrences(of: "[^A-Za-z0-9-]", with: "-", options: .regularExpression).prefix(40)
        let name = EventLog.shared.save(data, named: String(format: "snap-%03d-%@.jpg", count, String(safe)))
        EventLog.shared.log(.snap, "\(name) url=\(webView.url?.absoluteString ?? "-")")
    }
}
