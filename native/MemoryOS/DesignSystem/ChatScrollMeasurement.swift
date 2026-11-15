import SwiftUI

/// Presentation-only performance events. The view receives no storage or provider API.
@MainActor
protocol ChatScrollMeasuring: AnyObject, Sendable {
  func userScrollChanged(_ active: Bool)
}

private struct ChatScrollMeasurementKey: EnvironmentKey {
  static let defaultValue: (any ChatScrollMeasuring)? = nil
}

extension EnvironmentValues {
  var chatScrollMeasurement: (any ChatScrollMeasuring)? {
    get { self[ChatScrollMeasurementKey.self] }
    set { self[ChatScrollMeasurementKey.self] = newValue }
  }
}
