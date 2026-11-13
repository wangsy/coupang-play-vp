import Foundation
import Testing
import WebKit
@testable import CoupangPlayVP

/// Cinema A2: the page's fullscreen is emulated in the page and reported to the app.
@MainActor
@Suite(.serialized)
struct FullscreenShimTests {
    private static let page = """
    <!doctype html><html><body style="margin:0">
    <div style="height:2000px">
      <div id="player" style="position:relative; margin:40px; width:300px; height:200px"><video></video></div>
    </div>
    <script>
      window.changes = 0;
      document.addEventListener('fullscreenchange', () => window.changes++);
    </script>
    </body></html>
    """

    private func loaded() async throws -> (WKWebView, States) {
        let states = States()
        let bridge = FullscreenBridge()
        bridge.onChange = { states.items.append($0) }
        let webView = WebViewFactory.makeWebView(
            configuration: WebViewFactory.makeConfiguration(dataStore: .nonPersistent(), fullscreenBridge: bridge))
        webView.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let waiter = Waiter()
        webView.navigationDelegate = waiter
        webView.loadHTMLString(Self.page, baseURL: URL(string: "https://www.coupangplay.com/play/"))
        try await waiter.wait()
        return (webView, states)
    }

    private func state(_ webView: WKWebView) async throws -> String {
        let value = try await webView.evaluateJavaScript("""
        (() => { const p = document.getElementById('player'); const r = p.getBoundingClientRect();
          return JSON.stringify({ isPlayer: document.fullscreenElement === p, webkit: document.webkitFullscreenElement === p,
            any: document.fullscreenElement !== null, changes: window.changes,
            fills: r.left === 0 && r.top === 0 && r.width === innerWidth && r.height === innerHeight }); })()
        """)
        return try #require(value as? String)
    }

    private func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<40 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }

    @Test func enterAndExit() async throws {
        let (webView, states) = try await loaded()
        #expect(try await webView.evaluateJavaScript("document.fullscreenEnabled") as? Bool == true)

        _ = try await webView.evaluateJavaScript("document.getElementById('player').requestFullscreen(); 1")
        #expect(try await state(webView) == #"{"isPlayer":true,"webkit":true,"any":true,"changes":1,"fills":true}"#)
        #expect(await eventually { states.items == [true] })

        _ = try await webView.evaluateJavaScript("document.exitFullscreen(); 1")
        #expect(try await state(webView) == #"{"isPlayer":false,"webkit":false,"any":false,"changes":2,"fills":false}"#)
        #expect(await eventually { states.items == [true, false] })
    }

    @Test func escapeAndWebkitPrefixedCalls() async throws {
        let (webView, states) = try await loaded()
        _ = try await webView.evaluateJavaScript("document.getElementById('player').webkitRequestFullscreen(); 1")
        #expect(try await state(webView).contains(#""isPlayer":true"#))
        _ = try await webView.evaluateJavaScript("document.dispatchEvent(new KeyboardEvent('keydown', {key: 'Escape', bubbles: true})); 1")
        #expect(try await state(webView).contains(#""any":false"#))
        #expect(await eventually { states.items == [true, false] })
    }

    @Test func appCanEndIt() async throws {
        let (webView, states) = try await loaded()
        _ = try await webView.evaluateJavaScript("document.getElementById('player').requestFullscreen(); 1")
        _ = try await webView.evaluateJavaScript("window.__cpvpExitFullscreen(); 1")
        #expect(try await state(webView).contains(#""any":false"#))
        #expect(await eventually { states.items == [true, false] })
    }
}

@MainActor
private final class States {
    var items: [Bool] = []
}

@MainActor
private final class Waiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?
    private var done: Result<Void, Error>?

    func wait() async throws {
        if let done { return try done.get() }
        try await withCheckedThrowingContinuation { continuation = $0 }
    }

    private func finish(_ result: Result<Void, Error>) {
        guard done == nil else { return }
        done = result
        continuation?.resume(with: result)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish(.success(())) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
}
