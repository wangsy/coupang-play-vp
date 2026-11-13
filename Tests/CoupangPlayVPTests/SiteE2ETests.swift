import Foundation
import Testing
import WebKit
@testable import CoupangPlayVP

/// A4 (spec §4) against the real site — network, so only with `CPVP_E2E=1`
/// (`TEST_RUNNER_CPVP_E2E=1 xcodebuild test …`). Never logs in.
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["CPVP_E2E"] == "1"))
struct SiteE2ETests {
    /// Waits until `condition` holds or `seconds` pass.
    private func eventually(_ seconds: Double, _ condition: () async -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return await condition()
    }

    private func js(_ source: String, in webView: WKWebView) async throws -> String {
        let value = try await webView.evaluateJavaScript(source)
        return try #require(value as? String)
    }

    @Test func homeLoadsAndLooksLikeMac() async throws {
        let model = BrowserModel(startURL: SiteConfig.home)
        let loaded = await eventually(20) { model.webView.url?.host == "www.coupangplay.com" && !model.webView.isLoading }
        #expect(loaded)
        let probe = try await js(
            "JSON.stringify([navigator.maxTouchPoints, navigator.platform, 'ontouchstart' in window])",
            in: model.webView)
        #expect(probe == #"[0,"MacIntel",false]"#)
    }

    /// The "start / log in" call-to-action must lead to a web login, not the App Store (research R3).
    @Test func loginButtonGoesToWebLogin() async throws {
        let model = BrowserModel(startURL: SiteConfig.home)
        #expect(await eventually(20) { model.webView.url?.host == "www.coupangplay.com" && !model.webView.isLoading })
        // Let React hydrate and render the navbar.
        let clickable = """
        JSON.stringify([...document.querySelectorAll('a,button')]
          .filter(e => /시작하기|로그인/.test(e.textContent || ''))
          .map(e => ({ tag: e.tagName, text: (e.textContent || '').trim().slice(0, 30), href: e.getAttribute('href') })))
        """
        #expect(await eventually(15) { ((try? await js(clickable, in: model.webView)) ?? "[]") != "[]" })
        let found = try await js(clickable, in: model.webView)
        print("CTA candidates: \(found)")
        #expect(!found.contains("app.link"))
        #expect(!found.contains("apps.apple.com"))

        let before = model.webView.url
        _ = try await js("""
        (() => { const e = [...document.querySelectorAll('a,button')].find(e => /시작하기|로그인/.test(e.textContent || ''));
          e.click(); return (e.textContent || '').trim(); })()
        """, in: model.webView)
        // Through /oauth2/login to the Coupang login page, which must render (not Access Denied — research R5).
        let reached = await eventually(25) { model.webView.url?.host == "login.coupang.com" && !model.webView.isLoading }
        print("after click: \(model.webView.url?.host ?? "-")\(model.webView.url?.path ?? "") title=\(model.webView.title ?? "-")")
        #expect(reached)
        #expect(model.webView.url != before)
        #expect(model.webView.customUserAgent == SiteConfig.tabletUserAgent)
        #expect(model.webView.title == "로그인")
    }
}
