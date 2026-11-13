import SwiftUI
import WebKit

/// Puts the model's `WKWebView` into SwiftUI.
struct WebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WebViewContainer { WebViewContainer(webView: webView) }
    func updateUIView(_ container: WebViewContainer, context: Context) { container.setNeedsLayout() }
}

/// Keeps the web view exactly the size of the window.
///
/// After element fullscreen (the site's player) WebKit hands the web view back with the frame it had in the
/// fullscreen window (959×539 in a 1280×800 window → the page sits in the top-left corner). SwiftUI does not
/// lay out again because its own size did not change, so this container re-applies its bounds on every layout
/// and a few times after fullscreen ends (spec S10).
final class WebViewContainer: UIView {
    let webView: WKWebView
    private var observation: NSKeyValueObservation?

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        addSubview(webView)
        observation = webView.observe(\.fullscreenState, options: [.new]) { [weak self] webView, _ in
            MainActor.assumeIsolated { self?.fullscreenChanged(webView.fullscreenState) }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        fit("layout")
    }

    private func fullscreenChanged(_ state: WKWebView.FullscreenState) {
        EventLog.shared.log(.ui, "web fullscreen \(state.label) frame=\(Self.size(webView.frame)) container=\(Self.size(bounds))")
        guard state == .notInFullscreen else { return }
        // WebKit restores its saved frame asynchronously; check again after it is done.
        for delay in [0.0, 0.3, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.fit("after fullscreen +\(delay)s") }
        }
    }

    private func fit(_ reason: String) {
        guard webView.superview === self, webView.fullscreenState == .notInFullscreen, bounds.width > 0,
              webView.frame != bounds else { return }
        EventLog.shared.log(.ui, "web frame \(Self.size(webView.frame)) → \(Self.size(bounds)) (\(reason))")
        webView.frame = bounds
    }

    private static func size(_ rect: CGRect) -> String {
        "\(Int(rect.width))x\(Int(rect.height))@\(Int(rect.minX)),\(Int(rect.minY))"
    }
}

private extension WKWebView.FullscreenState {
    var label: String {
        switch self {
        case .notInFullscreen: "off"
        case .enteringFullscreen: "entering"
        case .inFullscreen: "on"
        case .exitingFullscreen: "exiting"
        @unknown default: "unknown"
        }
    }
}
