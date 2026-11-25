import Foundation
import Testing
import WebKit
@testable import CoupangPlayVP

/// Experiment DC12 (intent 261125-cinema-center-controls, research R6): `uhd-request.js` adds `x-support-uhd: true`
/// to the site's play request when the site says HEVC works and did not ask for UHD itself.
/// Requests go to 127.0.0.1:9 (nothing listens), so no test reaches the network; the headers are read from
/// `page-events.js`'s request logging, which sits underneath.
@MainActor
@Suite(.serialized)
struct UHDRequestTests {
    private static let play = "https://127.0.0.1:9/api/playback/play"

    private func loaded(requestUHD: Bool = true) async throws -> (WKWebView, Lines) {
        let lines = Lines()
        let events = PageEventBridge()
        events.onEvent = { _, _, line in lines.items.append(line) }
        let webView = WebViewFactory.makeWebView(configuration: WebViewFactory.makeConfiguration(
            dataStore: .nonPersistent(), eventBridge: events, requestUHD: requestUHD))
        webView.loadHTMLString("<!doctype html><p>play</p>", baseURL: URL(string: "https://www.coupangplay.com/play/"))
        #expect(await eventually { lines.items.contains { $0.contains("lifecycle") && $0.contains("\"load\"") } })
        return (webView, lines)
    }

    private func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<60 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return condition()
    }

    private func xhr(_ url: String, _ headers: [(String, String)], in webView: WKWebView) async throws {
        let set = headers.map { "x.setRequestHeader('\($0.0)', '\($0.1)');" }.joined()
        _ = try await webView.evaluateJavaScript("{ const x = new XMLHttpRequest(); x.open('POST', '\(url)'); \(set) x.send('{}'); } 1")
    }

    private func uhdHeader(for url: String) -> String {
        #"main play-header {"name":"x-support-uhd","url":"\#(url)","value":"true"}"#
    }

    @Test func addsToXHRPlayRequest() async throws {
        let (webView, lines) = try await loaded()
        try await xhr(Self.play, [("x-support-hevc", "true")], in: webView)
        #expect(await eventually { lines.items.contains(where: { $0.contains(uhdHeader(for: Self.play)) }) })
        #expect(await eventually {
            lines.items.contains { $0.contains("main player-uhd") && $0.contains(#""event":"added""#) && $0.contains(#""via":"xhr""#) }
        })
    }

    @Test func addsToFetchPlayRequest() async throws {
        let (webView, lines) = try await loaded()
        _ = try await webView.evaluateJavaScript(
            "fetch('\(Self.play)', { method: 'POST', headers: { 'x-support-hevc': 'true' } }).catch(() => {}); 1")
        #expect(await eventually { lines.items.contains(where: { $0.contains(uhdHeader(for: Self.play)) }) })
        #expect(lines.items.contains { $0.contains("main player-uhd") && $0.contains(#""via":"fetch""#) })
    }

    @Test func leavesOtherRequestsAlone() async throws {
        let (webView, lines) = try await loaded()
        let other = "https://127.0.0.1:9/api/playback/other"
        try await xhr(other, [("x-support-hevc", "true")], in: webView)                          // not the play request
        try await xhr(Self.play, [("x-support-hevc", "false")], in: webView)                     // no HEVC
        try await xhr(Self.play, [("x-support-hevc", "true"), ("x-support-uhd", "true")], in: webView) // site asked itself
        #expect(await eventually { lines.items.filter { $0.contains("main play-header") }.count >= 4 })
        try? await Task.sleep(for: .milliseconds(500))
        #expect(!lines.items.contains { $0.contains("main player-uhd") })
        #expect(lines.items.filter { $0.contains(#""name":"x-support-uhd""#) }.count == 1) // only the site's own
    }

    @Test func offWhenNotRequested() async throws {
        let (webView, lines) = try await loaded(requestUHD: false)
        try await xhr(Self.play, [("x-support-hevc", "true")], in: webView)
        #expect(await eventually { lines.items.contains { $0.contains("main play-header") && $0.contains("x-support-hevc") } })
        try? await Task.sleep(for: .milliseconds(500))
        #expect(!lines.items.contains { $0.contains(#""name":"x-support-uhd""#) })
    }
}

@MainActor
private final class Lines {
    var items: [String] = []
}
