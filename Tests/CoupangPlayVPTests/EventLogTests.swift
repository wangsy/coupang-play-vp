import Foundation
import Testing
import WebKit
@testable import CoupangPlayVP

/// S9: secrets are masked before logging.
struct LogRedactionTests {
    @Test(arguments: [
        ("https://www.coupangplay.com/login/callback?code=abc123&state=x", "https://www.coupangplay.com/login/callback?code=***&state=***"),
        ("https://a.test/#access_token=eyJ.abc.def&x=1", "https://a.test/#access_token=***&x=1"),
        ("rtnUrl=https%3A%2F%2Fa%3Fcode%3Dsecret", "rtnUrl=https%3A%2F%2Fa%3Fcode%3D***"),
        ("login.pang?response_type=code&state=54c6&nonce=3oUb&code_challenge=5_oV", "login.pang?response_type=code&state=***&nonce=***&code_challenge=***"),
        ("Authorization: Bearer abc.DEF-123", "Authorization: Bearer ***"),
        ("{\"password=hunter2\"}", "{\"password=***\"}"),
        ("https://www.coupangplay.com/titles/123?sourcePage=home", "https://www.coupangplay.com/titles/123?sourcePage=home"),
        ("returnPath=%2F&isSignup=false", "returnPath=%2F&isSignup=false"),
    ])
    func masks(_ pair: (String, String)) {
        #expect(LogRedaction.text(pair.0) == pair.1)
    }
}

/// S9: page-events.js reports to the app — main frame and iframe — and never sends typed values.
@MainActor
@Suite(.serialized)
struct PageEventsTests {
    private static let page = """
    <!doctype html><html><body>
    <input id="secret" type="password" name="pw">
    <button id="go">시작하기</button>
    <iframe id="child" srcdoc="<!doctype html><script>console.warn('from child')</script>"></iframe>
    <script>console.log('hello', {a: 1}); history.pushState({}, '', '/next');</script>
    </body></html>
    """

    private func loaded() async throws -> (WKWebView, Lines) {
        let lines = Lines()
        let bridge = PageEventBridge()
        bridge.onEvent = { _, _, line in lines.items.append(line) }
        let webView = WebViewFactory.makeWebView(
            configuration: WebViewFactory.makeConfiguration(dataStore: .nonPersistent(), eventBridge: bridge))
        webView.loadHTMLString(Self.page, baseURL: URL(string: "https://www.coupangplay.com/events/"))
        #expect(await eventually { lines.items.contains { $0.contains("lifecycle") && $0.contains("\"load\"") } })
        return (webView, lines)
    }

    private func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<80 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return condition()
    }

    @Test func reportsConsoleRoutesIdentityAndChildFrames() async throws {
        let (_, lines) = try await loaded()
        let all = lines.items.joined(separator: "\n")
        #expect(all.contains("main console {\"level\":\"log\",\"text\":\"hello {\\\"a\\\":1}\"}"))
        #expect(all.contains("main route {\"how\":\"pushState\",\"to\":\"https://www.coupangplay.com/next\"}"))
        #expect(all.contains("main identity") && all.contains("\"maxTouchPoints\":0") && all.contains("\"platform\":\"MacIntel\""))
        #expect(all.contains("sub console {\"level\":\"warn\",\"text\":\"from child\"}"))
    }

    @Test func reportsClicksAndFocusWithoutValues() async throws {
        let (webView, lines) = try await loaded()
        _ = try await webView.evaluateJavaScript("""
        const i = document.getElementById('secret'); i.value = 'hunter2'; i.focus();
        i.dispatchEvent(new KeyboardEvent('keydown', {key: 'h', bubbles: true}));
        document.getElementById('go').click(); 1
        """)
        #expect(await eventually { lines.items.contains { $0.contains("main click") } })
        let all = lines.items.joined(separator: "\n")
        #expect(all.contains("main focus {\"el\":{\"id\":\"secret\",\"name\":\"pw\",\"tag\":\"input\",\"type\":\"password\"}}"))
        #expect(all.contains("main key {\"inField\":true,\"key\":\"char\"}"))
        #expect(all.contains("\"text\":\"시작하기\""))
        #expect(!all.contains("hunter2"))
    }
}

@MainActor
private final class Lines {
    var items: [String] = []
}
