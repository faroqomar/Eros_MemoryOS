import CryptoKit
import Darwin
import Foundation
import MemoryCore
import MemorySQLite

protocol LockProbing: Sendable {
  func prepare() async throws
  func checkLocked() async throws -> String
  func verifyUnlocked() async throws
}

/// Uses the real graph writer in this app's separate sandbox. All content is fictional.
actor ArchiveLockProbe: LockProbing {
  private let directory: URL
  private let control: URL
  private var expected: PersonalMemorySnapshot?
  private var digest: SHA256.Digest?
  private var file: URL { directory.appending(path: "memory.json") }

  init() {
    let base = URL.applicationSupportDirectory
    directory = base.appending(path: "LockProbe")
    control = base.appending(path: "fictional-control.txt")
  }

  func prepare() async throws {
    try? FileManager.default.removeItem(at: directory)
    let repository = FilePersonalMemoryRepository(url: file)
    let useCases = PersonalMemoryUseCases(repository: repository)
    _ = try await useCases.ingest(
      source: PersonalMemorySource(text: "I prefer fictional blue notebooks", origin: "lock-test"))
    let snapshot = try await useCases.snapshot()
    let reopened = try await FilePersonalMemoryRepository(url: file).load()
    guard snapshot == reopened else { throw ProbeFailure("Unlocked archive mismatch") }
    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
    let folder = try FileManager.default.attributesOfItem(atPath: directory.path)
    guard attributes[.protectionKey] as? FileProtectionType == .complete,
      folder[.protectionKey] as? FileProtectionType == .complete
    else { throw ProbeFailure("Complete protection metadata missing") }
    expected = snapshot
    digest = SHA256.hash(data: try freshRead(file))
    // Negative control contains no personal data and must remain readable when locked.
    try Data("fictional-control".utf8).write(to: control, options: .atomic)
    try FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.none], ofItemAtPath: control.path)
  }

  func checkLocked() throws -> String {
    guard try freshRead(control) == Data("fictional-control".utf8) else {
      throw ProbeFailure("Control read failed; result inconclusive")
    }
    do {
      _ = try freshRead(file)
      throw ProbeFailure(
        "FAIL: protected archive was readable while protected data was unavailable")
    } catch let error as POSIXError where error.code == .EACCES || error.code == .EPERM {
      return "Protected disk read denied (POSIX \(error.code.rawValue)); control read passed."
    }
  }

  func verifyUnlocked() async throws {
    guard let expected, let digest,
      SHA256.hash(data: try freshRead(file)).elementsEqual(digest),
      try await FilePersonalMemoryRepository(url: file).load() == expected
    else { throw ProbeFailure("Unlocked archive recovery or exact-byte check failed") }
  }

  private func freshRead(_ url: URL) throws -> Data {
    let descriptor = Darwin.open(url.path, O_RDONLY)
    guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    defer { Darwin.close(descriptor) }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while true {
      let count = Darwin.read(descriptor, &buffer, buffer.count)
      guard count >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
      if count == 0 { return result }
      result.append(contentsOf: buffer.prefix(count))
    }
  }
}

struct ProbeFailure: Error, LocalizedError {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}
