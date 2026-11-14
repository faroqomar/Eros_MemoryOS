import Foundation
import MemoryCore
import MemorySQLite

@main struct Benchmark {
  static func elapsedMS(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
  }
  static func text(_ index: Int) -> String {
    let prefix = "Fictional thought \(index) / فكرة تجريبية عن مشروع القراءة. "
    return prefix + String(repeating: "a", count: 1024 - prefix.utf8.count)
  }
  static func stats(_ values: [Double]) -> [String:Double] {
    let sorted = values.sorted(), mean = values.reduce(0,+) / Double(values.count)
    let variance = values.map { pow($0 - mean, 2) }.reduce(0,+) / Double(values.count)
    return ["min_ms":sorted.first!, "max_ms":sorted.last!, "mean_ms":mean,
      "median_ms": (sorted.count % 2 == 0 ? (sorted[sorted.count/2-1] + sorted[sorted.count/2])/2 : sorted[sorted.count/2]), "p95_nearest_rank_ms": sorted[Int(ceil(Double(sorted.count)*0.95))-1],
      "population_standard_deviation_ms":sqrt(variance)]
  }
  @MainActor static func main() async throws {
    let directory=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    let url=directory.appendingPathComponent("records.sqlite")
    let repository=try SQLiteRecordRepository(url:url)
    let originals=(0..<1000).map { n in LocalRecord(kind:.capture,originalText:text(n),text:text(n)) }
    let archive=try RecordArchive(snapshot:RecordSnapshot(records:originals)).encoded()
    try await repository.restoreArchive(archive)
    let model=LocalRecordsViewModel(useCases:LocalMemoryUseCases(repository:repository))
    await model.load()
    guard model.records.count==1000 && model.error==nil else { throw LocalMemoryError.storageFailure }
    let clock=ContinuousClock()
    var saves:[Double]=[]
    for n in 1000..<1030 {
      model.draft=text(n)
      let start=clock.now
      let committed=await model.saveCapture()
      let elapsed=elapsedMS(start.duration(to:clock.now))
      guard committed && model.error==nil && model.draft.isEmpty && model.records.count==n+1 else { throw LocalMemoryError.storageFailure }
      saves.append(elapsed)
    }
    var opens:[Double]=[]
    for _ in 0..<5 {
      let start=clock.now
      let reopened=try SQLiteRecordRepository(url:url)
      let freshModel=LocalRecordsViewModel(useCases:LocalMemoryUseCases(repository:reopened))
      await freshModel.load()
      let elapsed=elapsedMS(start.duration(to:clock.now))
      guard freshModel.records.count==1030 && freshModel.error==nil else { throw LocalMemoryError.storageFailure }
      opens.append(elapsed)
    }
    let final=try await repository.snapshot()
    guard Set(final.records.map(\.id)).count==1030 && final.records.allSatisfy({$0.originalText.utf8.count==1024}) else { throw LocalMemoryError.storageFailure }
    var sizes:[String:Int]=[:]
    for suffix in ["", "-journal", "-wal", "-shm"] {
      let path=url.path+suffix
      sizes["records.sqlite"+suffix]=(try? FileManager.default.attributesOfItem(atPath:path)[.size] as? Int) ?? 0
    }
    let result:[String:Any]=[
      "kind":"HOST diagnostic baseline only; not a physical-device result",
      "warm_save_path":"Actual LocalRecordsViewModel.saveCapture -> LocalMemoryUseCases.create -> SQLiteRecordRepository.create plus full snapshot/validation/VM refresh/sort; no UI layout/rendering",
      "api_reopen_path":"Fresh SQLiteRecordRepository initialization + fresh LocalRecordsViewModel + load/full snapshot; same process and OS filesystem caches remain warm; not app cold-launch timing",
      "configuration":"SwiftPM Release, Swift 6, macOS host; no file-protection emulation, cache purge, process-launch cost or UI rendering",
      "seed_records":1000,"warm_save_samples_count":saves.count,"reopen_samples_count":opens.count,
      "per_record_original_utf8_bytes":1024,"final_records":final.records.count,
      "warm_save_samples_ms":saves,"warm_save_statistics":stats(saves),
      "api_reopen_samples_ms":opens,"api_reopen_statistics":stats(opens),
      "file_sizes_bytes":sizes,"database_plus_journal_bytes":(sizes["records.sqlite"] ?? 0)+(sizes["records.sqlite-journal"] ?? 0),
      "final_retained_text_bytes":final.records.reduce(0){$0+$1.originalText.utf8.count},
      "checks":"All saves returned success; no VM error; drafts cleared after commit; 1,030 unique UUIDs and 1,024-byte originals survived final snapshot",
      "physical_benchmark_status":"BLOCKED: iPhone15ProMax Release p95 save <200ms, cold snapshot <1s, DB+journal <10MiB remain unmeasured on required hardware",
      "database_directory":directory.path
    ]
    let data=try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys])
    print(String(decoding:data,as:UTF8.self))
  }
}
