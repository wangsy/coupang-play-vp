import Foundation
import Testing
import WebKit
@testable import CoupangPlayVP

/// Spec A2 (intent 261125-cinema-center-controls): the middle controls over a fake site player.
@MainActor
@Suite(.serialized)
struct CenterControlsTests {
    /// The site's player, cut down to what `center-controls.js` looks for (research R4). The site handles clicks
    /// by delegation (like React): one document listener records which site button got it.
    private static let page = """
    <!doctype html><html><body style="margin:0">
    <div id="playerPage">
      <div id="playerWrapper" style="position:absolute; left:0; top:0; width:800px; height:600px">
        <div class="PlaybackControls_playbackControls__x" style="position:absolute; inset:0">
          <div class="playpause-toggler" style="position:absolute; inset:0"></div>
          <div id="bottom" class="buttons-bottom" style="position:absolute; left:0; right:0; bottom:0; height:60px">
            <div class="playpause-button PlayPause_playPauseButton__a"><img alt=""></div>
            <div class="fr-button RewindButton_rewindButton__b"><img alt=""></div>
            <div class="fr-button ForwardButton_forwardButton__c"><img alt=""></div>
            <div id="next" class="nextEpisode-button NextEpisode_nextEpisode__d" role="button"><div class="label">다음화</div><svg></svg></div>
            <div class="fullscreen-button Fullscreen_fullscreen__e"><img alt=""></div>
          </div>
        </div>
        <video></video>
      </div>
    </div>
    <script>
      window.clicks = [];
      const names = { 'playpause-button': 'playpause', 'RewindButton_rewindButton__b': 'rewind',
        'ForwardButton_forwardButton__c': 'forward', 'nextEpisode-button': 'next', 'fullscreen-button': 'fullscreen' };
      document.addEventListener('click', (e) => {
        const button = e.target.closest && e.target.closest('.playpause-button, .fr-button, .nextEpisode-button, .fullscreen-button');
        const toggler = e.target.closest && e.target.closest('.playpause-toggler');
        if (toggler) window.clicks.push('toggler');
        if (!button) return;
        const name = Object.keys(names).find((c) => button.classList.contains(c));
        window.clicks.push(names[name]);
        if (name === 'fullscreen-button') {
          if (document.fullscreenElement) document.exitFullscreen(); else document.getElementById('playerPage').requestFullscreen();
        }
      });
    </script>
    </body></html>
    """

    private func loaded(base: String = "https://www.coupangplay.com/play/") async throws -> (WKWebView, Lines) {
        let lines = Lines()
        let events = PageEventBridge()
        events.onEvent = { _, _, line in lines.items.append(line) }
        let webView = WebViewFactory.makeWebView(configuration: WebViewFactory.makeConfiguration(
            dataStore: .nonPersistent(), eventBridge: events, fullscreenBridge: FullscreenBridge(), centerControls: true))
        webView.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        webView.loadHTMLString(Self.page, baseURL: URL(string: base))
        #expect(await eventually { lines.items.contains { $0.contains("lifecycle") && $0.contains("\"load\"") } })
        return (webView, lines)
    }

    private func eventually(_ condition: () async -> Bool) async -> Bool {
        for _ in 0..<100 {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return await condition()
    }

    private func js(_ source: String, in webView: WKWebView) async -> String {
        let value = try? await webView.evaluateJavaScript("String((() => { \(source) })())")
        return value as? String ?? "<error>"
    }

    private func visible(_ webView: WKWebView) async -> String {
        await js("const l = document.getElementById('cpvp-center'); return l ? l.dataset.visible : 'none'", in: webView)
    }

    private func press(_ name: String, in webView: WKWebView) async {
        _ = await js("document.querySelector('#cpvp-center button[data-name=\(name)]').click(); return 1", in: webView)
    }

    private func label(_ name: String, in webView: WKWebView) async -> String {
        await js("return document.querySelector('#cpvp-center button[data-name=\(name)]').getAttribute('aria-label')", in: webView)
    }

    @Test func mountsInWrapperHiddenThenFollowsSite() async throws {
        let (webView, _) = try await loaded()
        #expect(await eventually { await js("return !!document.querySelector('#playerWrapper > #cpvp-center')", in: webView) == "true" })
        #expect(await visible(webView) == "0")
        _ = await js("document.getElementById('bottom').classList.add('shown'); return 1", in: webView)
        #expect(await eventually { await visible(webView) == "1" })
        _ = await js("document.getElementById('bottom').classList.remove('shown'); return 1", in: webView)
        #expect(await eventually { await visible(webView) == "0" })
    }

    @Test func tapShowsAndButtonsPressTheSite() async throws {
        let (webView, lines) = try await loaded()
        _ = await js("document.querySelector('.playpause-toggler').dispatchEvent(new PointerEvent('pointerdown', {bubbles: true})); return 1", in: webView)
        #expect(await eventually { await visible(webView) == "1" })
        for name in ["playPause", "back10", "fwd10", "next"] { await press(name, in: webView) }
        // Our own clicks never reach the site's tap layer (spec P3).
        #expect(await js("return window.clicks.join(',')", in: webView) == "playpause,rewind,forward,next")
        #expect(await eventually { lines.items.contains { $0.contains("main player-center") && $0.contains(#""event":"press""#) && $0.contains(#""via":"site""#) } })
        #expect(lines.items.contains { $0.contains("main player-center") && $0.contains(#""event":"show""#) && $0.contains("tap") })
    }

    @Test func fullscreenButtonGoesThroughTheSiteAndTheShim() async throws {
        let (webView, _) = try await loaded()
        #expect(await eventually { await label("fullscreen", in: webView) == "전체화면" })
        await press("fullscreen", in: webView)
        #expect(await js("return document.fullscreenElement && document.fullscreenElement.id", in: webView) == "playerPage")
        #expect(await eventually { await label("fullscreen", in: webView) == "전체화면 끝내기" })
        // The layer is still on the player inside the fullscreen element.
        #expect(await js("return document.fullscreenElement.contains(document.getElementById('cpvp-center'))", in: webView) == "true")
        await press("fullscreen", in: webView)
        #expect(await js("return String(document.fullscreenElement)", in: webView) == "null")
        #expect(await eventually { await label("fullscreen", in: webView) == "전체화면" })
        #expect(await js("return window.clicks.join(',')", in: webView) == "fullscreen,fullscreen")
    }

    @Test func muteTogglesTheVideo() async throws {
        let (webView, _) = try await loaded()
        #expect(await eventually { await label("mute", in: webView) == "음소거" })
        await press("mute", in: webView)
        #expect(await js("return document.querySelector('video').muted", in: webView) == "true")
        #expect(await eventually { await label("mute", in: webView) == "소리 켜기" })
    }

    /// Intent Q5: once the video has played, it stays while paused and goes when playing again.
    @Test func pausedAfterPlayingStaysThenPlayingHides() async throws {
        let (webView, _) = try await loaded()
        #expect(await eventually { await visible(webView) == "0" })
        _ = await js("document.querySelector('video').dispatchEvent(new Event('play')); return 1", in: webView)
        #expect(await eventually { await visible(webView) == "1" })
        #expect(await label("playPause", in: webView) == "재생")
        _ = await js("Object.defineProperty(document.querySelector('video'), 'paused', { get: () => false, configurable: true }); return 1", in: webView)
        #expect(await eventually { await visible(webView) == "0" })
        #expect(await label("playPause", in: webView) == "멈춤")
    }

    private func info(_ webView: WKWebView) async -> String {
        await js("const i = document.querySelector('#cpvp-center .cpvp-info'); return i ? i.dataset.on + '|' + i.textContent : 'none'", in: webView)
    }

    /// Makes the (src-less) test video report a decoded size, then "plays" it once so it counts as played.
    private func fakeSize(_ w: Int, _ h: Int, in webView: WKWebView) async {
        _ = await js("""
        const v = document.querySelector('video');
        Object.defineProperty(v, 'videoWidth', { get: () => \(w), configurable: true });
        Object.defineProperty(v, 'videoHeight', { get: () => \(h), configurable: true });
        v.dispatchEvent(new Event('play')); return 1
        """, in: webView)
    }

    /// Addition 2026-11-25 (spec P6): the resolution shows while paused, named by the 16:9 height it fills.
    @Test(arguments: [
        (1920, 1080, "1080p FHD · 1920×1080"),
        (3840, 2160, "4K UHD · 3840×2160"),
        (2560, 1440, "1440p QHD · 2560×1440"),
        (1280, 720, "720p HD · 1280×720"),
        (1920, 800, "1080p FHD · 1920×800"),
        (960, 540, "540p · 960×540"),
    ])
    func resolutionWhilePaused(_ size: (Int, Int, String)) async throws {
        let (webView, _) = try await loaded()
        await fakeSize(size.0, size.1, in: webView)
        #expect(await eventually { await info(webView) == "1|\(size.2)" })
    }

    /// Changed 2026-11-25 (decision DC10): the resolution shows whenever the controls do, also while playing.
    @Test func resolutionShowsWhilePlayingToo() async throws {
        let (webView, _) = try await loaded()
        #expect(await eventually { await info(webView) == "0|" }) // size unknown → no line
        await fakeSize(1920, 1080, in: webView)
        _ = await js("Object.defineProperty(document.querySelector('video'), 'paused', { get: () => false, configurable: true }); return 1", in: webView)
        _ = await js("document.querySelector('.playpause-toggler').dispatchEvent(new PointerEvent('pointerdown', {bubbles: true})); return 1", in: webView)
        #expect(await eventually { await visible(webView) == "1" })
        #expect(await label("playPause", in: webView) == "멈춤")
        #expect(await info(webView) == "1|1080p FHD · 1920×1080")
    }

    @Test func nextIsHiddenWithoutTheSiteButton() async throws {
        let (webView, _) = try await loaded()
        #expect(await eventually { await js("return document.querySelector('#cpvp-center button[data-name=next]').parentElement.hidden", in: webView) == "false" })
        _ = await js("document.getElementById('next').remove(); return 1", in: webView)
        #expect(await eventually { await js("return document.querySelector('#cpvp-center button[data-name=next]').parentElement.hidden", in: webView) == "true" })
    }

    @Test func otherHostsGetNoLayer() async throws {
        let (webView, _) = try await loaded(base: "https://example.com/play/")
        try? await Task.sleep(for: .seconds(1))
        #expect(await visible(webView) == "none")
    }
}

@MainActor
private final class Lines {
    var items: [String] = []
}
