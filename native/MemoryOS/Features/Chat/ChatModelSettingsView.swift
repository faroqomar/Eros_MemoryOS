import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor @Observable
final class ChatModelPreparationViewModel {
  private let useCase: PrepareChatModel
  private(set) var isPreparing = false
  private(set) var result: Bool?
  init(useCase: PrepareChatModel) { self.useCase = useCase }
  func prepare(_ url: URL) async {
    guard !isPreparing else { return }
    isPreparing = true
    result = nil
    defer { isPreparing = false }
    do {
      try await useCase.execute(url)
      result = true
    } catch { result = false }
  }
  func selectionFailed() { result = false }
}

struct ChatModelSettingsView: View {
  let language: AppLanguage
  let model: ChatModelPreparationViewModel
  @State private var chooseFile = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(language.text("Experimental Qwen3 0.6B · Offline", "Qwen3 0.6B تجريبي · دون إنترنت"))
        .font(.headline)
      Text(
        language.text(
          "Import Qwen3-0.6B-Q4_K_M.gguf from Files. The app checks the reviewed file hash before use. No automatic download. Arabic answers may be inaccurate.",
          "استورد Qwen3-0.6B-Q4_K_M.gguf من الملفات. يتحقق التطبيق من بصمة الملف قبل استخدامه. لا يوجد تنزيل تلقائي. قد تخطئ الأجوبة العربية."
        )
      )
      .font(.callout).foregroundStyle(MemoryTheme.secondary)
      Button(
        language.text(
          model.isPreparing ? "Checking model…" : "Import local model",
          model.isPreparing ? "التحقق من النموذج…" : "استيراد نموذج محلي")
      ) {
        chooseFile = true
      }.disabled(model.isPreparing).frame(minHeight: 44).accessibilityIdentifier(
        "import-chat-model")
      if let success = model.result {
        Text(
          language.text(
            success
              ? "Model prepared. Return to Chat and retry."
              : "Could not prepare this file. Choose the reviewed GGUF model and check free space.",
            success
              ? "النموذج جاهز. ارجع إلى المحادثة وأعد المحاولة."
              : "تعذّر تجهيز الملف. اختر نموذج GGUF المعتمد وتحقق من المساحة.")
        )
        .font(.callout).accessibilityIdentifier("chat-model-result")
      }
    }
    .fileImporter(isPresented: $chooseFile, allowedContentTypes: [.data, .item]) { result in
      switch result {
      case .success(let url): Task { await model.prepare(url) }
      case .failure: model.selectionFailed()
      }
    }
  }
}
