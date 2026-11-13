import WebKit

/// Receives `fullscreen-shim.js` state changes (handler `cpvpFullscreen`) — cinema spec C1.
@MainActor
final class FullscreenBridge: NSObject, WKScriptMessageHandler {
    static let name = "cpvpFullscreen"

    var onChange: ((_ isFullscreen: Bool) -> Void)?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              let body = message.body as? [String: Any], let state = body["state"] as? String else { return }
        EventLog.shared.log(.media, "cinema page \(state)")
        onChange?(state == "enter")
    }
}
