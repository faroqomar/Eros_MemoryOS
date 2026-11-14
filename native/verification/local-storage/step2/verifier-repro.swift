import Foundation
import MemoryCore
import MemorySQLite

@main struct Repro {
 @MainActor static func main() async throws {
  if CommandLine.arguments.count > 2 {
   let repo = try SQLiteRecordRepository(url:URL(fileURLWithPath:CommandLine.arguments[2]))
   if CommandLine.arguments[1] == "seed" { _ = try await repo.create(kind:.capture,text:"Baseline أصل") }
   if CommandLine.arguments[1] == "snapshot" { print("recovered-record-count=\(try await repo.snapshot().records.count)") }
   if CommandLine.arguments[1] == "restore" {
    let date=Date(timeIntervalSinceReferenceDate:1)
    let records=(0..<20).map { n in
     let revisions=(0..<1000).map { r in RecordRevision(text:"revision \(n)-\(r)",createdAt:date) }
     return LocalRecord(kind:.capture,originalText:"incoming \(n)",text:revisions.last!.text,createdAt:date,revisions:revisions)
    }
    let data=try RecordArchive(snapshot:RecordSnapshot(records:records)).encoded()
    try await repo.restoreArchive(data)
    print("restore-completed")
   }
   return
  }
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  defer {try? FileManager.default.removeItem(at: dir)}
  let repo = try SQLiteRecordRepository(url:dir.appendingPathComponent("records.sqlite"))
  let composed = "\u{E9}"
  let decomposed = "e\u{301}"
  let record = try await repo.create(kind: .capture, text: composed)
  try await repo.correct(id:record.id,text:decomposed)
  let got = try await repo.snapshot().records[0]
  print("correction requested utf8=\(Array(decomposed.utf8)); retained utf8=\(Array(got.text.utf8)); revisionCount=\(got.revisions.count)")
  let mismatched = LocalRecord(kind:.capture, originalText:composed, text:decomposed)
  do {try RecordArchive(snapshot:RecordSnapshot(records:[mismatched])).validate(); print("mismatched archive current/original bytes accepted") } catch { print("mismatch rejected: \(error)") }
  let conflict = LocalRecord(id:record.id,kind:record.kind,originalText:decomposed,text:decomposed,createdAt:record.createdAt)
  do {try await repo.restoreArchive(RecordArchive(snapshot:RecordSnapshot(records:[conflict])).encoded()); print("same ID, changed source UTF8 restore accepted")} catch { print("source conflict rejected: \(error)") }
  let unavailable = LocalRecordsViewModel(useCases:nil)
  unavailable.draft="Keep unsaved"
  await unavailable.load()
  await unavailable.load()
  print("startup dependency nil after repeated Reload: canSave=\(unavailable.canSave), error=\(String(describing:unavailable.error)), draft=\(unavailable.draft)")
 }
}
