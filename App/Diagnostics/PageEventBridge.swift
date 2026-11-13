import Foundation
import WebKit

/// Receives `page-events.js` messages (handler name `cpvp`) and writes them to `EventLog` (spec S9).
/// Holds its sink weakly so the user content controller does not keep the model alive.
@MainActor
final class PageEventBridge: NSObject, WKScriptMessageHandler {
    static let name = "cpvp"

    /// Called for every message after logging — the model uses it to take snapshots.
    var onEvent: ((_ kind: String, _ isMainFrame: Bool, _ line: String) -> Void)?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard var body = message.body as? [String: Any] else { return }
        let kind = body.removeValue(forKey: "kind") as? String ?? "?"
        let frame = body.removeValue(forKey: "frame") as? String ?? "?"
        let href = body.removeValue(forKey: "href") as? String ?? ""
        let rest = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let host = message.frameInfo.securityOrigin.host
        let category: EventLog.Category = kind == "media" || kind == "drm" || kind == "fullscreen" ? .media : .page
        let location = frame == "main" ? "" : " @\(host) \(href)"
        let line = "\(frame) \(kind) \(rest)\(location)"
        EventLog.shared.log(category, line)
        onEvent?(kind, message.frameInfo.isMainFrame, line)
    }
}
