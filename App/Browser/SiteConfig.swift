import Foundation

/// Constants for the one site this app shows (spec S1–S3).
enum SiteConfig {
    static let home = URL(string: "https://www.coupangplay.com/")!

    /// Where the window starts. Debug builds accept `-startURL <url>` as a launch argument (plan step 4).
    static var startURL: URL {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "startURL"), let url = URL(string: raw) {
            return url
        }
        #endif
        return home
    }

    /// Mac Safari user agent (spec S2, policy P1: fixed `Version/26.0`).
    static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"

    /// iPad Safari user agent for every other site. The Coupang login server denies this app's Mac UA (research R5).
    static let tabletUserAgent =
        "Mozilla/5.0 (iPad; CPU OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1"

    /// Top-level hosts shown as a Mac (spec S2). `mac-disguise.js` has the same list.
    static let macHostSuffix = "coupangplay.com"

    static func isMacHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == macHostSuffix || host.hasSuffix("." + macHostSuffix)
    }

    /// The user agent for a main-frame load of `url`. `nil` keeps the current one (about:, blob:, data:).
    static func userAgent(for url: URL) -> String? {
        guard let host = url.host, !host.isEmpty else { return nil }
        return isMacHost(host) ? userAgent : tabletUserAgent
    }

    /// Schemes the web view may navigate to. Anything else (e.g. `coupangplay://`) is an app hand-off (spec S3).
    static let allowedSchemes: Set<String> = ["http", "https", "about", "blob", "data"]

    /// Hosts that only lead to the App Store (research R3).
    static let blockedHosts: Set<String> = ["apps.apple.com", "itunes.apple.com"]

    /// Host suffixes for deep-link services that bounce to the App Store (Branch: `coupangplay.app.link`).
    static let blockedHostSuffixes: [String] = [".app.link"]
}
