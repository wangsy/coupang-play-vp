import Foundation

enum NavigationDecision: Equatable {
    case allow
    case block(reason: String)
}

/// Decides whether the web view may go to a URL (spec S3, policy P3). Pure — no WebKit, so it is unit-tested directly.
enum NavigationPolicy {
    static func decide(_ url: URL) -> NavigationDecision {
        guard let scheme = url.scheme?.lowercased() else {
            return .block(reason: "no scheme")
        }
        guard SiteConfig.allowedSchemes.contains(scheme) else {
            return .block(reason: "app scheme \(scheme)://")
        }
        guard let host = url.host?.lowercased() else {
            return .allow // about:blank, blob:, data:
        }
        if SiteConfig.blockedHosts.contains(host) {
            return .block(reason: "app store host \(host)")
        }
        if let suffix = SiteConfig.blockedHostSuffixes.first(where: { host.hasSuffix($0) || host == String($0.dropFirst()) }) {
            return .block(reason: "deep link host \(host) (\(suffix))")
        }
        return .allow
    }
}
