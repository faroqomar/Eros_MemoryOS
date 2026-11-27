import ChatCore
import Darwin
import Foundation
import LocalMemoryRetrieval
import MemoryCore
import MemorySQLite
import Testing

@testable import MemoryOS

#if targetEnvironment(simulator)
  /// Opt-in only: a test shim limits direct network through the stated verification method.
  /// Run this test alone. Localhost remains available for XCTest control; no host policy changes.
  @Suite(.serialized) @MainActor struct ConnectedOfflineUnderstandingTests {
    @Test(
      .enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_CONNECTED_OFFLINE_SHIM"] != nil),
      .timeLimit(.minutes(15)))
    func actualRepositoriesModelsAndRebuildWorkWithExternalNetworkDenied() async throws {
      let path = try #require(
        ProcessInfo.processInfo.environment["MEMORYOS_CONNECTED_OFFLINE_SHIM"])
      let handle = try #require(dlopen(path, RTLD_NOW | RTLD_LOCAL), "Load test-only policy shim")
      defer { dlclose(handle) }
      typealias Install = @convention(c) (UnsafeMutablePointer<CChar>?, Int) -> Int32
      typealias External = @convention(c) (Int32, Int32) -> Int32
      typealias Loopback = @convention(c) () -> Int32
      typealias Counter = @convention(c) () -> UInt64
      let install = unsafeBitCast(
        try #require(dlsym(handle, "memoryos_install_offline_policy")), to: Install.self)
      let external = unsafeBitCast(
        try #require(dlsym(handle, "memoryos_probe_external")), to: External.self)
      let loopback = unsafeBitCast(
        try #require(dlsym(handle, "memoryos_probe_loopback")), to: Loopback.self)
      let method = ProcessInfo.processInfo.environment["MEMORYOS_OFFLINE_METHOD"] ?? "kernel"
      var rejected: Counter?
      var faultHandle: UnsafeMutableRawPointer?
      defer { if let faultHandle { dlclose(faultHandle) } }
      if method == "api-interposition" {
        let faultPath = try #require(
          ProcessInfo.processInfo.environment["MEMORYOS_OFFLINE_INTERPOSER"])
        faultHandle = try #require(dlopen(faultPath, RTLD_NOW | RTLD_LOCAL))
        let enable = unsafeBitCast(
          try #require(dlsym(faultHandle, "memoryos_api_fault_install")), to: Loopback.self)
        rejected = unsafeBitCast(
          try #require(dlsym(faultHandle, "memoryos_api_fault_rejected")), to: Counter.self)
        try #require(enable() == 0, "Explicit API fault injection opt-in missing")
      } else {
        try #require(method == "kernel", "Unknown network verification method")
        var detail = [CChar](repeating: 0, count: 1_024)
        let installed = detail.withUnsafeMutableBufferPointer { buffer in
          install(buffer.baseAddress, buffer.count)
        }
        let message = detail.withUnsafeBufferPointer { buffer in
          String(cString: buffer.baseAddress!)
        }
        print("MEMORYOS_SIMULATOR_OFFLINE_POLICY pid=\(getpid()) \(message)")
        try #require(installed == 0, "Kernel policy installation failed: \(message)")
      }
      let ipv4TCP = external(AF_INET, 0)
      let ipv4UDP = external(AF_INET, 1)
      let ipv6TCP = external(AF_INET6, 0)
      let ipv6UDP = external(AF_INET6, 1)
      let localControl = loopback()
      print(
        "MEMORYOS_SIMULATOR_NETWORK ipv4TCP=\(ipv4TCP) ipv4UDP=\(ipv4UDP) ipv6TCP=\(ipv6TCP) ipv6UDP=\(ipv6UDP) loopback=\(localControl)"
      )
      try #require(ipv4TCP == EPERM && ipv4UDP == EPERM)
      try #require(ipv6TCP == EPERM && ipv6UDP == EPERM)
      for family in [AF_INET, AF_INET6] {
        try #require(external(family, 2) == EPERM, "connectx must fail")
        try #require(external(family, 3) == EPERM, "sendmsg must fail")
        try #require(Self.swiftExternal(family: family, datagram: false) == EPERM)
        try #require(Self.swiftExternal(family: family, datagram: true) == EPERM)
      }
      try #require(localControl == 0, "Localhost control must stay usable")
      if let rejected {
        try #require(rejected() >= 12, "Every explicit cross-image API probe must be intercepted")
        let beforeURL = rejected()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.timeoutIntervalForResource = 3
        config.waitsForConnectivity = false
        config.connectionProxyDictionary = [:]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        var urlFailure: Int?
        do {
          _ = try await session.data(from: URL(string: "https://192.0.2.1/")!)
        } catch {
          urlFailure = (error as NSError).code
        }
        try #require(urlFailure != nil, "URL loading must fail")
        try #require(rejected() > beforeURL, "URL loading must reach an intercepted API")
        print(
          "MEMORYOS_SIMULATOR_API_PROBE crossImage=true publicSocketAPIs=12 URLFailure=\(urlFailure!) rejected=\(rejected()) kernelIsolation=false"
        )
      }
      if ProcessInfo.processInfo.environment["MEMORYOS_OFFLINE_PROBE_ONLY"] == "1" { return }
      let beforeWorkflow = rejected?()

      let directory = URL.temporaryDirectory.appending(
        path: "memoryos-connected-offline-" + UUID().uuidString)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: directory) }
      let personalURL = directory.appending(path: "personal/memory.json")
      let personal = PersonalMemoryUseCases(
        repository: FilePersonalMemoryRepository(url: personalURL))
      let sqliteURL = directory.appending(path: "records.sqlite")
      let local = try SQLiteRecordRepository(url: sqliteURL)
      let project = try await local.create(
        kind: .project, text: "The Cedar project needs a permit.")
      let english = PersonalMemorySource(
        conversationID: UUID(), text: "Rana: Saturday at six works for me.",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        origin: "fictional offline fixture", kind: .conversationOnly)
      let arabic = PersonalMemorySource(
        conversationID: UUID(), text: "عمر يفضل أن نتحدث بهدوء عندما نختلف.",
        createdAt: Date(timeIntervalSince1970: 1_700_000_060),
        origin: "fictional offline fixture", kind: .conversationOnly)
      _ = try await personal.ingest(source: english)
      _ = try await personal.ingest(source: arabic)
      let model = LocalInferenceCoordinator(model: ChatComposition.makeModel())
      let keyword = LocalMemorySearch(
        directory: directory.appending(path: "keyword"), cactusModelDirectory: nil, provider: .wax)
      let cactus = LocalMemorySearch(
        directory: directory.appending(path: "semantic"),
        cactusModelDirectory: Bundle.main.resourceURL?.appending(path: "MemoryModels/Cactus"),
        provider: .cactus, minimumSimilarity: -1)
      let search = MemorySearchUseCases(
        keyword: keyword, semantic: LocalMeaningSearch(candidates: cactus, model: model),
        purgeProviders: {
          try await keyword.purge()
          try await cactus.purge()
        },
        readCollection: {
          MemorySearchCollection.make(
            personal: try await personal.snapshot(), local: try await local.snapshot())
        })
      let started = Date()
      let literal = try await search.search(query: "Saturday", mode: .keyword)
      try #require(literal.contains { $0.id == english.id && $0.passage == english.text })
      let meaning = try await search.search(query: "meeting time agreement", mode: .semantic)
      try #require(Set(meaning.map(\.id)) == [english.id])
      let arabicMeaning = try await search.search(
        query: "كيف نخفف الخلاف في كلامنا؟", mode: .semantic)
      try #require(Set(arabicMeaning.map(\.id)) == [arabic.id])
      print("MEMORYOS_SIMULATOR_OFFLINE_STEP multilingualSearch=true")

      let reportURL = directory.appending(path: "reports/review.json")
      let understanding = RelationshipUnderstandingUseCases(
        memory: personal, analyzer: LocalRelationshipAnalyzer(model: model),
        reports: FileRelationshipReportRepository(url: reportURL))
      let result = try await understanding.analyze(
        .init(
          sourceIDs: [english.id],
          question: "Identify the agreement in this message. Return one agreement finding.",
          relationship: .friend, focus: .discussion))
      try #require(result.findings.contains { $0.kind == .agreement })
      let evidence = result.findings.flatMap(\.evidence)
      try #require(!evidence.isEmpty)
      try #require(
        evidence.allSatisfy {
          $0.sourceID == english.id
            && Data(english.text.utf8).range(of: Data($0.quote.utf8)) != nil
        })
      _ = try await understanding.save(result)
      let reopenedUnderstanding = RelationshipUnderstandingUseCases(
        memory: PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: personalURL)),
        analyzer: LocalRelationshipAnalyzer(model: model),
        reports: FileRelationshipReportRepository(url: reportURL))
      try #require(try await reopenedUnderstanding.loadSaved().count == 1)
      print("MEMORYOS_SIMULATOR_OFFLINE_STEP analysisPersistenceReopen=true")

      try await understanding.invalidateReports()
      try await search.invalidateIndexes()
      let clarified = try await personal.resolve(sourceID: english.id, kind: .fact)
      let entry = try #require(
        clarified.currentEntries.first { $0.sourceIDs.contains(english.id) })
      _ = try await personal.updateEntry(
        id: entry.id, text: "The current plan is Friday at six.", confirmedChange: true)
      let corrected = try await search.collection()
      try #require(corrected.document(english.id)?.text == english.text)
      try #require(corrected.document(english.id)?.detail == "historicalOriginal")
      try #require(corrected.document(entry.id)?.text == "The current plan is Friday at six.")
      try #require(try await understanding.loadSaved().isEmpty)
      try await search.invalidateIndexes()
      _ = try await understanding.forgetSource(sourceID: english.id, confirmed: true)
      try #require(try await search.search(query: "Saturday", mode: .semantic).isEmpty)
      let final = try await search.collection()
      try #require(final.document(english.id) == nil && final.document(entry.id) == nil)
      try #require(final.document(project.id) != nil)
      let reopened = PersonalMemoryUseCases(
        repository: FilePersonalMemoryRepository(url: personalURL))
      try #require(try await reopened.snapshot().sources.map(\.id) == [arabic.id])
      let reopenedLocal = try SQLiteRecordRepository(url: sqliteURL)
      try #require(try await reopenedLocal.snapshot().records.contains { $0.id == project.id })
      print("MEMORYOS_SIMULATOR_OFFLINE_STEP correctionDeletionRebuildReopen=true")
      try await keyword.purge()
      try await cactus.purge()
      try await keyword.close()
      try await cactus.close()
      await model.unload()
      let afterWorkflow = rejected?()
      if let beforeWorkflow, let afterWorkflow {
        print(
          "MEMORYOS_SIMULATOR_API_WORKFLOW rejectedBefore=\(beforeWorkflow) rejectedAfter=\(afterWorkflow) attempts=\(afterWorkflow - beforeWorkflow)"
        )
      }
      try #require(external(AF_INET, 0) == EPERM && external(AF_INET, 1) == EPERM)
      try #require(loopback() == 0)
      print(
        "MEMORYOS_CONNECTED_OFFLINE_SIMULATOR passed=true pid=\(getpid()) seconds=\(Date().timeIntervalSince(started)) modelSHA256=\(ChatComposition.modelSHA256) fictionalDataOnly=true networkMethod=\(method)"
      )
    }

    /// Calls originate in the real XCTest image, separate from the injected/probe dylibs.
    private static func swiftExternal(family: Int32, datagram: Bool) -> Int32 {
      let fd = Darwin.socket(family, datagram ? SOCK_DGRAM : SOCK_STREAM, 0)
      guard fd >= 0 else { return errno }
      defer { Darwin.close(fd) }
      _ = fcntl(fd, F_SETFL, O_NONBLOCK)
      func perform(_ pointer: UnsafePointer<sockaddr>, _ length: socklen_t) -> Int32 {
        if datagram {
          var byte: UInt8 = 0
          return Darwin.sendto(fd, &byte, 1, 0, pointer, length) < 0 ? errno : 0
        }
        return Darwin.connect(fd, pointer, length) < 0 ? errno : 0
      }
      if family == AF_INET {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(9).bigEndian
        _ = "192.0.2.1".withCString { inet_pton(AF_INET, $0, &address.sin_addr) }
        return withUnsafePointer(to: &address) {
          $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            perform($0, socklen_t(MemoryLayout<sockaddr_in>.size))
          }
        }
      }
      var address = sockaddr_in6()
      address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
      address.sin6_family = sa_family_t(AF_INET6)
      address.sin6_port = UInt16(9).bigEndian
      _ = "2001:db8::1".withCString { inet_pton(AF_INET6, $0, &address.sin6_addr) }
      return withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          perform($0, socklen_t(MemoryLayout<sockaddr_in6>.size))
        }
      }
    }
  }
#endif
