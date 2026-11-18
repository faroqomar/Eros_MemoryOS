import Observation
import SwiftUI
import UIKit

@MainActor @Observable
final class LockTestModel {
  var status = "Ready"
  var detail = "Tap Start. Then lock this iPhone with its side button."
  var running = false
  private let probe: any LockProbing
  private var task: Task<Void, Never>?
  private var background = UIBackgroundTaskIdentifier.invalid

  init(probe: any LockProbing) { self.probe = probe }

  func start() {
    guard !running else { return }
    #if targetEnvironment(simulator)
      status = "Physical iPhone required"
      detail = "Simulator can preview this screen but cannot qualify device file protection."
      return
    #else
      running = true
      status = "Preparing fictional records"
      detail = "Keep this app open until it says Lock now."
      task = Task { [self] in
        defer {
          running = false
          endBackground()
        }
        do {
          guard UIApplication.shared.isProtectedDataAvailable else {
            throw ProbeFailure("Unlock this iPhone before starting")
          }
          try await probe.prepare()
          try Task.checkCancellation()
          background = UIApplication.shared.beginBackgroundTask(withName: "Lock probe") {
            [weak self] in
            self?.status = "Inconclusive"
            self?.detail = "iOS ended the test window. Unlock, return here, and retry."
            self?.task?.cancel()
            self?.endBackground()
          }
          guard background != .invalid else {
            throw ProbeFailure("iOS did not grant a background test window; retry")
          }
          status = "Lock now"
          detail =
            "Press the side button now. Leave the iPhone locked for 15 seconds. Then unlock and return here."
          let clock = ContinuousClock()
          let deadline = clock.now.advanced(by: .seconds(25))
          while UIApplication.shared.isProtectedDataAvailable {
            try Task.checkCancellation()
            guard clock.now < deadline else {
              throw ProbeFailure(
                "No protected-data lock observed. Ensure a passcode is enabled, then retry.")
            }
            try await Task.sleep(for: .milliseconds(100))
          }
          let lockedResult = try await probe.checkLocked()
          try Task.checkCancellation()
          guard !UIApplication.shared.isProtectedDataAvailable else {
            throw ProbeFailure("Phone unlocked during the disk check; retry")
          }
          // End the background allowance once the actual locked check completes.
          endBackground()
          status = "Locked read denied"
          detail = "\(lockedResult) Unlock the iPhone and return here."
          while !UIApplication.shared.isProtectedDataAvailable {
            try await Task.sleep(for: .milliseconds(250))
          }
          try await probe.verifyUnlocked()
          try Task.checkCancellation()
          status = "PASS"
          detail =
            "Unlocked read passed. Locked disk read was denied. Control stayed readable. After unlock, original bytes and archive recovery matched."
        } catch is CancellationError {
          if status != "Inconclusive" {
            status = "Inconclusive"
            detail = "Test interrupted. Retry."
          }
        } catch {
          status = "Not passed"
          detail = error.localizedDescription
        }
      }
    #endif
  }

  private func endBackground() {
    if background != .invalid { UIApplication.shared.endBackgroundTask(background) }
    background = .invalid
  }
}

struct LockTestView: View {
  @State var model: LockTestModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Image(systemName: "lock.shield").font(.largeTitle).foregroundStyle(.cyan)
        Text("MemoryOS Lock Test").font(.largeTitle.bold())
        Text("Fictional records · separate test app").foregroundStyle(.secondary)
        Text(model.status).font(.title.bold()).accessibilityIdentifier("lock-status")
        Text(model.detail).font(.body).accessibilityIdentifier("lock-detail")
        Button(model.running ? "Test running" : "Start") { model.start() }
          .buttonStyle(.borderedProminent).controlSize(.large).disabled(model.running)
        Text(
          "Use a passcode-protected physical iPhone. Restarting this app discards an unfinished result. This checks the personal graph file, not all app storage or battery use."
        )
        .font(.footnote).foregroundStyle(.secondary)
      }.padding(24)
    }.preferredColorScheme(.dark)
  }
}

@main
struct LockTestApp: App {
  var body: some Scene {
    WindowGroup { LockTestView(model: LockTestModel(probe: ArchiveLockProbe())) }
  }
}
