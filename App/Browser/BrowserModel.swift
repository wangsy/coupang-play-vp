import Observation
import WebKit

/// A JavaScript `alert` / `confirm` / `prompt` waiting for the user.
struct WebDialog: Identifiable {
    enum Kind: Equatable { case alert, confirm, prompt(defaultText: String) }
    let id = UUID()
    let kind: Kind
    let message: String
}

/// Owns the one web view, applies the navigation rules and logs everything it sees (spec S3, S4, S7, S8, S9).
@MainActor
@Observable
final class BrowserModel: NSObject {
    let webView: WKWebView
    private(set) var canGoBack = false
    private(set) var loadError: String?
    private(set) var dialog: WebDialog?
    /// The page is in (emulated) fullscreen → the app shows cinema mode (cinema spec C2).
    private(set) var isCinema = false
    /// Set by `CinemaSpace` while the immersive space is on screen.
    var cinemaSpaceIsOpen = false
    /// Counts "the user closed the browser window during cinema" (`ContentView`). `CinemaSpace` reacts by reopening
    /// the window and closing itself — fullscreen ends instead of leaving only the black room (cinema spec C2, decision D4).
    /// A counter, not a Bool: a late signal from the old window must not leave a stale "closed" state behind.
    private(set) var windowClosedDuringCinema = 0

    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var dialogAnswer: CheckedContinuation<(ok: Bool, text: String?), Never>?
    @ObservationIgnored private let bridge = PageEventBridge()
    @ObservationIgnored private let fullscreenBridge = FullscreenBridge()
    @ObservationIgnored private var snapshots: Snapshotter!
    private let log = EventLog.shared

    init(startURL: URL) {
        webView = WebViewFactory.makeWebView(configuration: WebViewFactory.makeConfiguration(eventBridge: bridge, fullscreenBridge: fullscreenBridge))
        super.init()
        snapshots = Snapshotter(webView: webView)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        bridge.onEvent = { [weak self] kind, isMainFrame, _ in self?.pageEvent(kind, isMainFrame: isMainFrame) }
        fullscreenBridge.onChange = { [weak self] on in
            guard let self, isCinema != on else { return }
            isCinema = on
            snapshots.capture(on ? "cinema-enter" : "cinema-exit", after: 1.5)
        }

        // WKWebView reports KVO changes on the main thread. Next.js changes pages with pushState,
        // which no navigation delegate call reports — so watch url/title/canGoBack directly.
        observations = [
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.canGoBack = webView.canGoBack }
            },
            webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.log.log(.nav, "url → \(webView.url?.absoluteString ?? "-")") }
            },
            webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.log.log(.nav, "title → \(webView.title ?? "-")") }
            },
        ]
        log.log(.nav, "start \(startURL.absoluteString) ua=\(webView.customUserAgent ?? "-")")
        log.log(.app, "log folder \(EventLog.shared.folder.path)")
        webView.load(URLRequest(url: startURL))
    }

    // MARK: Ornament (spec S7)

    func goBack() {
        log.log(.ui, "tap back (canGoBack=\(webView.canGoBack))")
        webView.goBack()
    }

    func reload() {
        log.log(.ui, "tap reload \(webView.url?.absoluteString ?? "-")")
        loadError = nil
        if webView.url == nil { webView.load(URLRequest(url: SiteConfig.home)) } else { webView.reload() }
    }

    func goHome() {
        log.log(.ui, "tap home")
        loadError = nil
        webView.load(URLRequest(url: SiteConfig.home))
    }

    // MARK: Cinema (cinema spec C2)

    /// The browser window went to the background (its close button). Only matters while in cinema.
    func browserWindowClosed() {
        log.log(.ui, "window closed (cinema \(isCinema ? "on" : "off"), space \(cinemaSpaceIsOpen ? "open" : "closed"))")
        guard isCinema, cinemaSpaceIsOpen else { return }
        windowClosedDuringCinema += 1
    }

    /// The system closed the cinema space (e.g. Digital Crown) — end the page's fullscreen too.
    func exitCinemaFromSystem() {
        guard isCinema else { return }
        log.log(.media, "cinema closed by system → exit page fullscreen")
        isCinema = false
        webView.evaluateJavaScript("window.__cpvpExitFullscreen && window.__cpvpExitFullscreen()", completionHandler: nil)
    }

    // MARK: Dialogs

    func answerDialog(ok: Bool, text: String? = nil) {
        log.log(.dialog, "answered ok=\(ok)")
        dialog = nil
        dialogAnswer?.resume(returning: (ok, text))
        dialogAnswer = nil
    }

    private func present(_ kind: WebDialog.Kind, _ message: String, from frame: WKFrameInfo) async -> (ok: Bool, text: String?) {
        if dialogAnswer != nil { answerDialog(ok: false) } // one at a time
        log.log(.dialog, "\(kind) from \(frame.securityOrigin.host): \(message)")
        dialog = WebDialog(kind: kind, message: message)
        snapshots.capture("dialog", after: 0.5)
        return await withCheckedContinuation { dialogAnswer = $0 }
    }

    // MARK: Page events → snapshots

    private func pageEvent(_ kind: String, isMainFrame: Bool) {
        switch kind {
        case "route" where isMainFrame: snapshots.capture("route", after: 1.5)
        case "click": snapshots.capture("after-click", after: 1.5)
        case "appear": snapshots.capture("appear", after: 0.8)
        case "js-error" where isMainFrame: snapshots.capture("js-error", after: 0.5)
        case "media", "drm", "fullscreen": snapshots.capture("media", after: 1.0)
        default: break
        }
    }

    private func show(_ error: Error, phase: String) {
        let nsError = error as NSError
        // Cancelled loads and loads we stopped by policy (WebKit "Frame load interrupted", 102) are not failures.
        let benign = (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
            || (nsError.domain == "WebKitErrorDomain" && nsError.code == 102)
        log.log(.nav, "\(phase) failed\(benign ? " (ignored)" : ""): \(nsError.domain) \(nsError.code) \(nsError.localizedDescription) "
            + "url=\((nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL)?.absoluteString ?? webView.url?.absoluteString ?? "-")")
        guard !benign else { return }
        loadError = nsError.localizedDescription
        snapshots.capture("load-failed", after: 0.5)
    }
}

extension BrowserModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .allow }
        let frame = navigationAction.targetFrame.map { $0.isMainFrame ? "main" : "sub" } ?? "new-window"
        let type = navigationAction.navigationType.label
        switch NavigationPolicy.decide(url) {
        case .allow:
            if frame != "sub", let agent = SiteConfig.userAgent(for: url), agent != webView.customUserAgent {
                webView.customUserAgent = agent // spec S2: Mac on Coupang Play, iPad elsewhere (research R5)
                log.log(.nav, "user agent → \(agent == SiteConfig.userAgent ? "Mac" : "iPad") for \(url.host ?? "-")")
            }
            if frame != "sub" || type != "other" { // sub-frame "other" loads are ads/trackers — too noisy
                log.log(.nav, "action \(type) \(frame) \(url.absoluteString) → allow")
            }
            return .allow
        case .block(let reason):
            log.log(.nav, "action \(type) \(frame) \(url.absoluteString) → BLOCK (\(reason))")
            snapshots.capture("blocked", after: 0.5)
            return .cancel
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        let response = navigationResponse.response
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if navigationResponse.isForMainFrame || status >= 400 {
            log.log(.nav, "response \(navigationResponse.isForMainFrame ? "main" : "sub") \(status) \(response.mimeType ?? "-") "
                + "\(response.url?.absoluteString ?? "-")")
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        log.log(.nav, "start-load \(webView.url?.absoluteString ?? "-")")
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        log.log(.nav, "redirect → \(webView.url?.absoluteString ?? "-")")
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        log.log(.nav, "commit \(webView.url?.absoluteString ?? "-")")
        if isCinema { isCinema = false } // a new document is never in fullscreen
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        log.log(.nav, "finish \(webView.url?.absoluteString ?? "-") title=\(webView.title ?? "-")")
        loadError = nil
        snapshots.capture("finish", after: 1.5)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        show(error, phase: "load")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        show(error, phase: "provisional")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        log.log(.nav, "web content process terminated — reloading \(webView.url?.absoluteString ?? "-")")
        webView.reload()
    }
}

extension BrowserModel: WKUIDelegate {
    /// New windows (`window.open`, `target=_blank`) open in the same web view (spec S4).
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        let url = navigationAction.request.url
        let decision = url.map(NavigationPolicy.decide) ?? .block(reason: "no url")
        log.log(.nav, "new-window \(url?.absoluteString ?? "-") → \(decision == .allow ? "same view" : "BLOCK")")
        if decision == .allow {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async {
        _ = await present(.alert, message, from: frame)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async -> Bool {
        await present(.confirm, message, from: frame).ok
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo
    ) async -> String? {
        let answer = await present(.prompt(defaultText: defaultText ?? ""), prompt, from: frame)
        return answer.ok ? answer.text : nil
    }

    func webViewDidClose(_ webView: WKWebView) {
        log.log(.nav, "page called window.close()")
    }
}

private extension WKNavigationType {
    var label: String {
        switch self {
        case .linkActivated: "link"
        case .formSubmitted: "form"
        case .backForward: "back-forward"
        case .reload: "reload"
        case .formResubmitted: "form-resubmit"
        case .other: "other"
        @unknown default: "unknown"
        }
    }
}
