import SwiftUI

/// The web view plus a small ornament so the user never gets stuck (spec S7, S8), and the page's JS dialogs.
struct ContentView: View {
    @State private var model = BrowserModel(startURL: SiteConfig.startURL)
    @State private var promptText = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        WebView(webView: model.webView)
            .overlay {
                if let message = model.loadError {
                    VStack(spacing: 16) {
                        Text("페이지를 불러오지 못했습니다")
                            .font(.title2)
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button("다시 시도") { model.reload() }
                    }
                    .padding(32)
                    .glassBackgroundEffect()
                }
            }
            .ornament(attachmentAnchor: .scene(.bottom)) {
                HStack(spacing: 8) {
                    Button { model.goBack() } label: {
                        Label("뒤로", systemImage: "chevron.backward")
                    }
                    .disabled(!model.canGoBack)
                    Button { model.reload() } label: {
                        Label("새로고침", systemImage: "arrow.clockwise")
                    }
                    Button { model.goHome() } label: {
                        Label("홈", systemImage: "house")
                    }
                }
                .labelStyle(.iconOnly)
                .padding(12)
                .glassBackgroundEffect()
            }
            .alert(
                model.dialog?.message ?? "",
                isPresented: Binding(
                    get: { model.dialog != nil },
                    set: { if !$0, model.dialog != nil { model.answerDialog(ok: false) } }
                ),
                presenting: model.dialog
            ) { dialog in
                switch dialog.kind {
                case .alert:
                    Button("확인") { model.answerDialog(ok: true) }
                case .confirm:
                    Button("취소", role: .cancel) { model.answerDialog(ok: false) }
                    Button("확인") { model.answerDialog(ok: true) }
                case .prompt:
                    TextField("", text: $promptText)
                    Button("취소", role: .cancel) { model.answerDialog(ok: false) }
                    Button("확인") { model.answerDialog(ok: true, text: promptText) }
                }
            }
            .onChange(of: model.dialog?.id) {
                if case .prompt(let defaultText) = model.dialog?.kind { promptText = defaultText }
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                EventLog.shared.log(.app, "scene \(phase)")
            }
            .onGeometryChange(for: CGSize.self, of: { $0.size }) { size in
                EventLog.shared.log(.ui, "window \(Int(size.width))x\(Int(size.height))")
            }
    }
}
