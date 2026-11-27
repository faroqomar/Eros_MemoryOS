import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor @Observable
final class ChatModelPreparationViewModel {
  private let useCase: PrepareChatModel
  private var operation: Task<Void, Error>?
  private(set) var isPreparing = false
  private(set) var isCancelling = false
  private(set) var result: Bool?
  private(set) var failure: ChatModelPreparationFailure?
  var asset: ChatModelAsset { useCase.asset }

  init(useCase: PrepareChatModel) { self.useCase = useCase }

  func prepare(_ url: URL) async {
    guard !isPreparing else { return }
    isPreparing = true
    result = nil
    failure = nil
    let task = Task { try await useCase.execute(url) }
    operation = task
    defer {
      operation = nil
      isPreparing = false
      isCancelling = false
    }
    do {
      try await withTaskCancellationHandler {
        try await task.value
      } onCancel: {
        task.cancel()
      }
      result = true
    } catch is CancellationError {
      result = nil
    } catch {
      failure = (error as? ChatModelPreparationFailure) ?? .couldNotSave
      result = false
    }
  }

  func cancel() {
    guard let operation else { return }
    isCancelling = true
    operation.cancel()
  }

  func selectionFailed(_ error: Error) {
    guard (error as? CocoaError)?.code != .userCancelled, !isPreparing else { return }
    failure = .unreadableFile
    result = false
  }
}

struct ChatModelSettingsView: View {
  let language: AppLanguage
  let model: ChatModelPreparationViewModel
  @State private var chooseFile = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(
        language.text(
          "Experimental \(model.asset.name) · Offline", "\(model.asset.name) تجريبي · دون إنترنت"),
        systemImage: "cpu"
      )
      .font(.headline)
      .accessibilityAddTraits(.isHeader)
      Text(
        language.text(
          "The included model runs chat offline. To reinstall it, choose this file in Files.",
          "يشغّل النموذج المضمّن المحادثة دون إنترنت. لإعادة تثبيته، اختر هذا الملف من تطبيق الملفات."
        )
      )
      .font(.callout).foregroundStyle(MemoryTheme.secondary)
      Text(model.asset.filename)
        .font(.footnote.monospaced())
        .foregroundStyle(MemoryTheme.secondary)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
      if model.isPreparing {
        ProgressView(
          language.text(
            model.isCancelling ? "Cancelling import…" : "Checking model…",
            model.isCancelling ? "إلغاء الاستيراد…" : "التحقق من النموذج…"))
        Button(language.text("Cancel import", "إلغاء الاستيراد"), action: model.cancel)
          .disabled(model.isCancelling).frame(minHeight: 44)
          .accessibilityIdentifier("cancel-chat-model-import")
      } else {
        Button {
          chooseFile = true
        } label: {
          Label(language.text("Import local model", "استيراد نموذج محلي"), systemImage: "folder")
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("import-chat-model")
      }
      if let success = model.result {
        Label(
          success
            ? language.text(
              "Model prepared. Return to Chat and retry.",
              "النموذج جاهز. ارجع إلى المحادثة وأعد المحاولة.") : failureMessage,
          systemImage: success ? "checkmark.circle" : "exclamationmark.circle"
        )
        .font(.callout).accessibilityIdentifier("chat-model-result")
      }
    }
    .fileImporter(isPresented: $chooseFile, allowedContentTypes: [.data, .item]) { result in
      switch result {
      case .success(let url): Task { await model.prepare(url) }
      case .failure(let error): model.selectionFailed(error)
      }
    }
  }

  private var failureMessage: String {
    switch model.failure {
    case .differentModel:
      language.text(
        "This file does not match the reviewed model. Choose \(model.asset.filename). Your previous model is still available.",
        "هذا الملف لا يطابق النموذج المعتمد. اختر \(model.asset.filename). لا يزال النموذج السابق متاحًا."
      )
    case .notEnoughSpace:
      language.text(
        "There is not enough space to import the model. Free some storage and retry.",
        "لا توجد مساحة كافية لاستيراد النموذج. حرّر بعض المساحة ثم أعد المحاولة.")
    case .unreadableFile:
      language.text(
        "The file could not be read. Download it in Files, then choose it again.",
        "تعذّرت قراءة الملف. نزّله في تطبيق الملفات، ثم اختره مجددًا.")
    case .couldNotSave, nil:
      language.text(
        "The model could not be saved. Keep the device unlocked, check storage, and retry.",
        "تعذّر حفظ النموذج. أبقِ الجهاز مفتوحًا، وتحقق من مساحة التخزين، ثم أعد المحاولة.")
    case .busy:
      language.text(
        "Another model import is still running. Wait for it to finish, then retry.",
        "لا يزال استيراد نموذج آخر قيد التنفيذ. انتظر حتى ينتهي، ثم أعد المحاولة.")
    }
  }
}
