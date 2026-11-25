import Foundation
import Testing
import WebKit
@testable import CoupangPlayVP

/// Layout research for intent 261125-cinema-center-controls: in fullscreen — and in the normal window once the player
/// (`#playerPage`) is tapped — `page-events.js` reports the player's outline (where the controls are) and every change
/// in how many controls are visible (wake / auto-hide).
@MainActor
@Suite(.serialized)
struct PlayerProbeTests {
    /// A tiny player like the site's: a full-size tap layer over the video and a bottom bar that the tap layer wakes.
    private static let page = """
    <!doctype html><html><body style="margin:0">
    <div id="playerPage" style="position:relative; width:400px; height:300px">
      <video></video>
      <div class="toggler" style="position:absolute; inset:0; cursor:pointer"></div>
      <div id="bar" class="bar" style="position:absolute; left:0; right:0; bottom:0; height:40px">
        <button aria-label="재생">P</button>
        <img class="icon" alt="전체화면" style="width:24px; height:24px; cursor:pointer"
          src="data:image/gif;base64,R0lGODlhAQABAAAAACwAAAAAAQABAAA=">
      </div>
    </div>
    <script>
      document.querySelector('.toggler').addEventListener('pointerdown', () => {
        document.getElementById('bar').style.opacity = '1';
      });
    </script>
    </body></html>
    """

    private func loaded() async throws -> (WKWebView, Lines) {
        let lines = Lines()
        let events = PageEventBridge()
        events.onEvent = { _, _, line in lines.items.append(line) }
        let webView = WebViewFactory.makeWebView(configuration: WebViewFactory.makeConfiguration(
            dataStore: .nonPersistent(), eventBridge: events, fullscreenBridge: FullscreenBridge()))
        webView.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        webView.loadHTMLString(Self.page, baseURL: URL(string: "https://www.coupangplay.com/play/"))
        #expect(await eventually { lines.items.contains { $0.contains("lifecycle") && $0.contains("\"load\"") } })
        return (webView, lines)
    }

    private func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return condition()
    }

    @Test func outlineOnEnterThenVisibilityChangesAndTap() async throws {
        let (webView, lines) = try await loaded()
        _ = try await webView.evaluateJavaScript("document.getElementById('playerPage').requestFullscreen(); 1")

        // Outline 1 s after entering: the bar and its labelled controls, with positions.
        #expect(await eventually { lines.items.contains { $0.contains("main player-outline") && $0.contains(#""reason":"enter""#) } })
        let outline = try #require(lines.items.first { $0.contains("main player-outline") })
        #expect(outline.contains(#""mode":"fullscreen""#))
        #expect(outline.contains(#""e":"div#bar.bar""#))
        #expect(outline.contains(#""aria-label":"재생""#))
        #expect(outline.contains(#""alt":"전체화면""#))
        #expect(outline.contains(#""viewport":"800x600""#))
        // Baseline: tap layer + button + image are all visible.
        #expect(await eventually { lines.items.contains { $0.contains("main player-visible") && $0.contains(#""visible":3"#) } })

        // The site hides its bar → one control left (the tap layer).
        _ = try await webView.evaluateJavaScript("document.getElementById('bar').style.opacity = '0'; 1")
        #expect(await eventually { lines.items.contains { $0.contains("main player-visible") && $0.contains(#""visible":1"#) } })

        // A tap wakes the bar: visible again, measured from the tap, and a second outline.
        _ = try await webView.evaluateJavaScript(
            "document.querySelector('.toggler').dispatchEvent(new PointerEvent('pointerdown', {bubbles: true})); 1")
        #expect(await eventually {
            lines.items.contains { $0.contains("main player-visible") && $0.contains(#""visible":3"#) && $0.contains(#""was":1"#)
                && !$0.contains(#""sinceTap":null"#) }
        })
        #expect(await eventually { lines.items.contains { $0.contains("main player-outline") && $0.contains(#""reason":"tap""#) } })
    }

    /// Intent Q1: the normal window's player too — a tap on `#playerPage` starts watching it.
    @Test func windowPlayerOnTap() async throws {
        let (webView, lines) = try await loaded()
        _ = try await webView.evaluateJavaScript(
            "document.querySelector('.toggler').dispatchEvent(new PointerEvent('pointerdown', {bubbles: true})); 1")
        #expect(await eventually {
            lines.items.contains { $0.contains("main player-outline") && $0.contains(#""mode":"window""#) && $0.contains(#""reason":"tap""#) }
        })
        #expect(await eventually { lines.items.contains { $0.contains("main player-visible") && $0.contains(#""mode":"window""#) } })
    }

    @Test func stopsAfterExit() async throws {
        let (webView, lines) = try await loaded()
        _ = try await webView.evaluateJavaScript("document.getElementById('playerPage').requestFullscreen(); 1")
        #expect(await eventually { lines.items.contains { $0.contains("main player-outline") } })
        _ = try await webView.evaluateJavaScript("document.exitFullscreen(); 1")
        try? await Task.sleep(for: .milliseconds(300))
        let count = lines.items.filter { $0.contains("main player-") }.count
        _ = try await webView.evaluateJavaScript("document.getElementById('bar').style.opacity = '0'; 1")
        try? await Task.sleep(for: .seconds(1.5))
        #expect(lines.items.filter { $0.contains("main player-") }.count == count)
    }
}

@MainActor
private final class Lines {
    var items: [String] = []
}
