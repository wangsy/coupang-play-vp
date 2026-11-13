import Foundation
import Testing
import WebKit
@testable import CoupangPlayVP

/// A2 (spec §4): in the configured web view, the main frame and an iframe both look like Mac Safari.
@MainActor
@Suite(.serialized)
struct DisguiseTests {
    private static let page = """
    <!doctype html><html><body>
    <iframe id="child" srcdoc="<!doctype html><p>child</p>"></iframe>
    </body></html>
    """

    /// Reads the values the site's detection libraries look at (research R2), as JSON.
    private static func probe(_ scope: String) -> String {
        """
        (() => { const w = \(scope); return JSON.stringify({
          maxTouchPoints: w.navigator.maxTouchPoints,
          platform: w.navigator.platform,
          userAgent: w.navigator.userAgent,
          ontouchstartInWindow: "ontouchstart" in w,
          ontouchstartInDocument: "ontouchstart" in w.document,
          ontouchstartInElement: "ontouchstart" in w.document.createElement("div"),
          standaloneInNavigator: "standalone" in w.navigator,
        }); })()
        """
    }

    private struct Probe: Decodable, Equatable {
        let maxTouchPoints: Int
        let platform: String
        let userAgent: String
        let ontouchstartInWindow: Bool
        let ontouchstartInDocument: Bool
        let ontouchstartInElement: Bool
        let standaloneInNavigator: Bool
    }

    private static let expected = Probe(
        maxTouchPoints: 0,
        platform: "MacIntel",
        userAgent: SiteConfig.userAgent,
        ontouchstartInWindow: false,
        ontouchstartInDocument: false,
        ontouchstartInElement: false,
        standaloneInNavigator: false
    )

    private func loadedWebView(base: String = "https://www.coupangplay.com/") async throws -> WKWebView {
        let webView = WebViewFactory.makeWebView(configuration: WebViewFactory.makeConfiguration(dataStore: .nonPersistent()))
        let waiter = LoadWaiter()
        webView.navigationDelegate = waiter
        webView.loadHTMLString(Self.page, baseURL: URL(string: base))
        try await waiter.wait()
        return webView
    }

    private func read(_ scope: String, in webView: WKWebView) async throws -> Probe {
        let value = try await webView.evaluateJavaScript(Self.probe(scope))
        let json = try #require(value as? String)
        return try JSONDecoder().decode(Probe.self, from: Data(json.utf8))
    }

    @Test func mainFrameLooksLikeMac() async throws {
        let webView = try await loadedWebView()
        #expect(try await read("window", in: webView) == Self.expected)
    }

    @Test func iframeLooksLikeMac() async throws {
        let webView = try await loadedWebView()
        #expect(try await read("document.getElementById('child').contentWindow", in: webView) == Self.expected)
    }

    /// Other sites (the Coupang login) keep the engine's own values — the script must not touch them (spec S2, research R5).
    @Test(arguments: ["https://login.coupang.com/login/", "https://example.com/"])
    func otherHostsAreLeftAlone(_ base: String) async throws {
        let webView = try await loadedWebView(base: base)
        let native = try await webView.evaluateJavaScript("""
        String(Object.getOwnPropertyDescriptor(Navigator.prototype, 'maxTouchPoints').get).includes('[native code]')
          && String(Object.getOwnPropertyDescriptor(Navigator.prototype, 'platform').get).includes('[native code]')
        """)
        #expect(native as? Bool == true)
    }

    @Test func iframeOfOtherOriginInsideCoupangPlayLooksLikeMac() async throws {
        let webView = try await loadedWebView()
        // srcdoc frames report the parent through ancestorOrigins.
        let ancestors = try await webView.evaluateJavaScript(
            "Array.from(document.getElementById('child').contentWindow.location.ancestorOrigins || []).join(',')")
        #expect((ancestors as? String)?.contains("coupangplay.com") == true)
    }

    @Test func httpUserAgentIsMac() {
        let webView = WebViewFactory.makeWebView(configuration: WebViewFactory.makeConfiguration(dataStore: .nonPersistent()))
        #expect(webView.customUserAgent == SiteConfig.userAgent)
    }
}

/// Resumes when the page (and its iframes) finished loading.
@MainActor
private final class LoadWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?
    private var result: Result<Void, Error>?

    func wait() async throws {
        if let result { return try result.get() }
        try await withCheckedThrowingContinuation { self.continuation = $0 }
    }

    private func finish(_ result: Result<Void, Error>) {
        guard self.result == nil else { return }
        self.result = result
        continuation?.resume(with: result)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish(.success(())) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }
}
