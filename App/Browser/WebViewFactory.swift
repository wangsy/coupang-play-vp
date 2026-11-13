import WebKit

/// Builds the web view the app and the tests share (spec S2, S5, S6, S8, S9).
@MainActor
enum WebViewFactory {
    /// `mac-disguise.js` from the app bundle.
    static let disguiseScriptSource = bundledScript("mac-disguise")
    /// `page-events.js` from the app bundle.
    static let pageEventsScriptSource = bundledScript("page-events")

    private static func bundledScript(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("\(name).js missing from the app bundle")
        }
        return source
    }

    /// - Parameter eventBridge: receives `page-events.js` messages. `nil` leaves page events unreported.
    static func makeConfiguration(
        dataStore: WKWebsiteDataStore = .default(),
        eventBridge: PageEventBridge? = nil
    ) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore // .default() persists cookies → login survives relaunch (S5)
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let controller = configuration.userContentController
        controller.addUserScript(WKUserScript(source: disguiseScriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        if let eventBridge {
            controller.add(eventBridge, name: PageEventBridge.name)
            controller.addUserScript(WKUserScript(source: pageEventsScriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        }
        return configuration
    }

    static func makeWebView(configuration: WKWebViewConfiguration = makeConfiguration()) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = SiteConfig.userAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.isInspectable = true // policy P2: always, so anyone building from source can debug the site
        return webView
    }
}
