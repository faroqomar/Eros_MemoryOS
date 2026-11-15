import AIEvaluationCore
import CactusEvaluationAdapter
import Foundation
import Testing

private func temporaryDirectory() throws -> URL {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "memoryos-cactus-contract-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  return directory
}

@Test(arguments: [true, false])
func remoteDirectoriesAreRejectedBeforeAnyFileAccess(_ remoteModel: Bool) async throws {
  let directory = try temporaryDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let remote = try #require(URL(string: "https://example.invalid/cactus-evaluation"))
  let adapter = CactusMemoryIndexAdapter(
    modelDirectory: remoteModel ? remote : directory,
    indexDirectory: remoteModel ? directory : remote)
  do {
    // An empty snapshot needs no assets. Reject invalid locations before it can succeed.
    try await adapter.rebuild(records: [])
    Issue.record("The local-only adapter accepted a remote model or index directory.")
  } catch EvaluationError.invalidSuite {
  } catch {
    Issue.record("Expected invalidSuite before location I/O, received: \(error)")
  }
  #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
}

@Test func missingAssetCannotProduceFakeRetrieval() async throws {
  let directory = try temporaryDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let adapter = CactusMemoryIndexAdapter(
    modelDirectory: directory.appendingPathComponent("missing"),
    indexDirectory: directory.appendingPathComponent("index"))
  await #expect(throws: EvaluationError.self) {
    try await adapter.rebuild(records: [
      .init(id: "source", text: "Fictional source", language: "en")
    ])
  }
  await #expect(throws: EvaluationError.self) {
    _ = try await adapter.search(query: "source", limit: 1)
  }
}

@Test func emptySnapshotAndClosePreserveUnrelatedOriginalFiles() async throws {
  let directory = try temporaryDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let original = directory.appendingPathComponent("canonical-original.txt")
  let originalBytes = Data("Café نور 🌙".utf8)
  try originalBytes.write(to: original)
  let adapter = CactusMemoryIndexAdapter(
    modelDirectory: directory.appendingPathComponent("missing"), indexDirectory: directory)
  try await adapter.rebuild(records: [])
  #expect(try await adapter.search(query: "anything", limit: 3).isEmpty)
  await adapter.close()
  #expect(try Data(contentsOf: original) == originalBytes)
}

@Test func duplicateIDsFailBeforeOpeningModelOrIndex() async throws {
  let directory = try temporaryDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let adapter = CactusMemoryIndexAdapter(
    modelDirectory: directory, indexDirectory: directory.appendingPathComponent("derived"))
  await #expect(throws: EvaluationError.self) {
    try await adapter.rebuild(records: [
      .init(id: "same", text: "First original", language: "en"),
      .init(id: "same", text: "Second original", language: "en"),
    ])
  }
  #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("derived").path))
}

@Test func cancelledRebuildCannotPublishResults() async throws {
  let directory = try temporaryDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let adapter = CactusMemoryIndexAdapter(
    modelDirectory: directory, indexDirectory: directory.appendingPathComponent("derived"))
  let task = Task {
    while !Task.isCancelled { await Task.yield() }
    try await adapter.rebuild(records: [
      .init(id: "source", text: "Fictional source", language: "en")
    ])
  }
  task.cancel()
  await #expect(throws: CancellationError.self) { try await task.value }
  await #expect(throws: EvaluationError.self) {
    _ = try await adapter.search(query: "source", limit: 1)
  }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"] != nil))
func realEmbeddingIndexSupportsArabicAndMixedSourceIDs() async throws {
  let modelPath = try #require(ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"])
  let directory = try temporaryDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let records: [SourceRecord] = [
    .init(id: "عيد-ميلاد", text: "عيد ميلاد زينب كريم هو ٢٣ تشرين الأول.", language: "ar"),
    .init(
      id: "mixed-Café🌙", text: "مشروع Cedar موعده 18 July. The artist is Café نور 🌙.",
      language: "ar-en"),
    .init(
      id: "bakery", text: "حسن گال يمكن نسوي موقع للمخبز، بس بعدنا ما اتفقنا.", language: "ar-IQ"),
  ]
  let originals = records.map { Data($0.text.utf8) }
  let adapter = CactusMemoryIndexAdapter(
    modelDirectory: URL(fileURLWithPath: modelPath), indexDirectory: directory)
  try await adapter.rebuild(records: records)
  let arabic = try await adapter.search(query: "متى عيد ميلاد زينب كريم؟", limit: 3)
  #expect(arabic.first?.sourceID == "عيد-ميلاد")
  let mixed = try await adapter.search(query: "Cedar موعد المشروع", limit: 3)
  #expect(mixed.first?.sourceID == "mixed-Café🌙")
  #expect(
    (arabic + mixed).allSatisfy {
      $0.score?.isFinite == true && records.map(\.id).contains($0.sourceID)
    })
  #expect(records.map { Data($0.text.utf8) } == originals)
  await adapter.close()
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"] != nil))
func realCorrectionAndRemovalRebuildNeverReturnDeletedSourceIDs() async throws {
  let modelPath = try #require(ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"])
  let directory = try temporaryDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let adapter = CactusMemoryIndexAdapter(
    modelDirectory: URL(fileURLWithPath: modelPath), indexDirectory: directory,
    minimumSimilarity: -1)
  try await adapter.rebuild(records: [
    .init(id: "date", text: "Original Saffron date: 10 August.", language: "en"),
    .init(id: "remove", text: "Fictional obsolete record.", language: "en"),
  ])
  try await adapter.rebuild(records: [
    .init(id: "date", text: "Corrected Saffron date: 11 August.", language: "en", revision: 2)
  ])
  let results = try await adapter.search(query: "What is the corrected Saffron date?", limit: 3)
  #expect(results.map(\.sourceID) == ["date"])
  await #expect(throws: EvaluationError.self) {
    try await adapter.rebuild(records: [.init(id: "bad", text: "", language: "en")])
  }
  #expect(try await adapter.search(query: "Saffron", limit: 3).map(\.sourceID) == ["date"])
  try await adapter.rebuild(records: [])
  #expect(try await adapter.search(query: "Saffron", limit: 3).isEmpty)
  await adapter.close()
}

@Test func embeddedNullTextCannotSilentlyTruncateAtTheCBoundary() async throws {
  let directory = try temporaryDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let adapter = CactusMemoryIndexAdapter(
    modelDirectory: directory, indexDirectory: directory.appendingPathComponent("derived"))
  await #expect(throws: EvaluationError.self) {
    try await adapter.rebuild(records: [
      .init(id: "source", text: "Original\u{0}source suffix", language: "en")
    ])
  }
  await #expect(throws: EvaluationError.self) {
    _ = try await adapter.search(query: "query\u{0}suffix", limit: 1)
  }
  #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("derived").path))
}

@Test func runtimeRequiresTheLocalOnlyBuildGuardAndCPUBackend() {
  #expect(CactusMemoryIndexAdapter.isLocalOnlyRuntime)
  #expect(CactusMemoryIndexAdapter.isCPUBackendAvailable)
  if let setting = ProcessInfo.processInfo.environment["CACTUS_NUM_THREADS"],
    let expected = Int(setting), expected > 0
  {
    #expect(CactusMemoryIndexAdapter.configuredWorkerCount == min(expected, 16))
  }
}

@Test func modifiedManifestCannotAuthorizeDifferentWeights() async throws {
  let directory = try temporaryDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let counterfeit: [String: Any] = [
    "repository": "Cactus-Compute/Qwen3-Embedding-0.6B",
    "revision": CactusMemoryIndexAdapter.modelRevision,
    "archiveSHA256": CactusMemoryIndexAdapter.modelArchiveSHA256,
    "files": ["config.txt": String(repeating: "0", count: 64)],
  ]
  try JSONSerialization.data(withJSONObject: counterfeit).write(
    to: directory.appendingPathComponent(".memoryos-asset-manifest.json"))
  let adapter = CactusMemoryIndexAdapter(
    modelDirectory: directory, indexDirectory: directory.appendingPathComponent("derived"))
  await #expect(
    throws: EvaluationError.unavailable(
      "The Cactus model manifest SHA-256 differs from the reviewed asset.")
  ) {
    try await adapter.rebuild(records: [
      .init(id: "source", text: "Fictional source", language: "en")
    ])
  }
  #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("derived").path))
}
