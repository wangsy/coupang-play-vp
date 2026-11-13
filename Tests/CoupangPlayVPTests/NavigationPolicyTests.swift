import Foundation
import Testing
@testable import CoupangPlayVP

/// A3 (spec §4): app hand-offs are blocked, the site and the Coupang login pass.
struct NavigationPolicyTests {
    @Test(arguments: [
        "coupangplay://",
        "coupangplay://login/#Intent;scheme=https;package=com.coupang.mobile.play;end",
        "itms-apps://apps.apple.com/app/id1536885649",
        "https://apps.apple.com/kr/app/%EC%BF%A0%ED%8C%A1%ED%94%8C%EB%A0%88%EC%9D%B4/id1536885649",
        "https://itunes.apple.com/kr/app/id1536885649",
        "https://coupangplay.app.link/l57BMr1B8zb?cta_name=NAVBAR_DOWNLOAD",
        "https://app.link/x",
    ])
    func blocksAppHandOffs(_ raw: String) throws {
        let url = try #require(URL(string: raw))
        #expect(NavigationPolicy.decide(url) != .allow)
    }

    @Test(arguments: [
        "https://www.coupangplay.com/",
        "https://www.coupangplay.com/login",
        "https://www.coupangplay.com/login/callback?code=x",
        "https://login.coupang.com/login/login.pang?rtnUrl=https%3A%2F%2Fwww.coupangplay.com%2F",
        "https://assets.coupangplay.com/_next/static/chunks/main.js",
        "about:blank",
        "about:srcdoc",
        "blob:https://www.coupangplay.com/1234",
        "data:text/html,hi",
        "https://notapp.link.example.com/",
    ])
    func allowsTheSite(_ raw: String) throws {
        let url = try #require(URL(string: raw))
        #expect(NavigationPolicy.decide(url) == .allow)
    }
}

/// Spec S2 (2026-11-13): Mac on Coupang Play, iPad elsewhere — the Coupang login denies the Mac UA (research R5).
struct UserAgentChoiceTests {
    @Test(arguments: [
        ("https://www.coupangplay.com/", true),
        ("https://coupangplay.com/home", true),
        ("https://assets.coupangplay.com/x.js", true),
        ("https://login.coupang.com/login/login.pang", false),
        ("https://www.coupang.com/", false),
        ("https://notcoupangplay.com/", false),
    ])
    func picksByHost(_ pair: (String, Bool)) throws {
        let url = try #require(URL(string: pair.0))
        #expect(SiteConfig.userAgent(for: url) == (pair.1 ? SiteConfig.userAgent : SiteConfig.tabletUserAgent))
    }

    @Test func keepsCurrentForHostless() throws {
        #expect(SiteConfig.userAgent(for: try #require(URL(string: "about:blank"))) == nil)
    }
}
