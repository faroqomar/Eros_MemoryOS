import ChatCore
import Foundation
import LlamaEvaluationAdapter
import Testing

@testable import MemoryOS

private final class ImportRuntimeLocation: @unchecked Sendable {
  let bundled: URL
  let imported: URL
  private let lock = NSLock()
  private var count = 0
  init(bundled: URL, imported: URL) {
    self.bundled = bundled
    self.imported = imported
  }
  func resolve() -> URL {
    lock.withLock { count += 1 }
    return FileManager.default.fileExists(atPath: imported.path) ? imported : bundled
  }
  var calls: Int { lock.withLock { count } }
}

/// Opt-in, serialized real SDK recovery. No app-owned Documents or model defaults change.
@Suite(
  .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_MODEL_IMPORT_RECOVERY"] == "1")
)
@MainActor struct ChatModelImportRuntimeTests {
  @Test(.timeLimit(.minutes(5)))
  func firstImportRepairsMissingAndCorruptBundleWithoutRestart() async throws {
    let root = URL.temporaryDirectory.appending(path: "import-runtime-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let asset = ChatComposition.modelAsset
    let directory = root.appending(path: "prepared")
    let location = ImportRuntimeLocation(
      bundled: root.appending(path: "missing-bundle.gguf"),
      imported: directory.appending(path: asset.filename))
    let model = LlamaChatModel(
      assetURL: location.bundled, expectedSHA256: asset.sha256,
      assetURLResolver: { location.resolve() })
    let turns = [ChatTurn(role: .user, text: "Return only the required JSON object.")]
    let grammar = #"root ::= "{\"ready\":true}""#
    do {
      for corrupt in [false, true] {
        if corrupt { try Data("fictional corrupt model".utf8).write(to: location.bundled) }
        await #expect(throws: ChatError.modelUnavailable) {
          _ = try await model.generateJSON(
            turns: turns, grammar: grammar, maximumOutputTokens: 32)
        }
      }
      #expect(location.calls == 2)
      let source = try #require(Bundle.main.resourceURL).appending(
        path: "MemoryModels/" + asset.filename)
      let clock = ContinuousClock()
      let startedImport = clock.now
      try await ChatModelImporter(asset: asset, directory: directory).prepare(from: source)
      let importSeconds = Self.seconds(startedImport.duration(to: clock.now))
      let startedRecovery = clock.now
      let first = try await model.generateJSON(
        turns: turns, grammar: grammar, maximumOutputTokens: 32)
      let recoverySeconds = Self.seconds(startedRecovery.duration(to: clock.now))
      #expect(first == #"{"ready":true}"#)
      #expect(location.calls == 3)
      let warm = try await model.generateJSON(
        turns: turns, grammar: grammar, maximumOutputTokens: 32)
      #expect(warm == first && location.calls == 3)
      await model.unload()
      let reloaded = try await model.generateJSON(
        turns: turns, grammar: grammar, maximumOutputTokens: 32)
      #expect(reloaded == first && location.calls == 4)
      #expect(try Data(contentsOf: location.bundled) == Data("fictional corrupt model".utf8))
      print(
        "MEMORYOS_IMPORT_RECOVERY passed=true bytes=\(asset.byteCount) importSeconds=\(importSeconds) recoverySeconds=\(recoverySeconds) coldResolutions=\(location.calls)"
      )
    } catch {
      await model.unload()
      throw error
    }
    await model.unload()
  }

  private static func seconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
  }
}
