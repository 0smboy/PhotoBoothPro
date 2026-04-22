import Foundation

enum FlashMode: String, CaseIterable, Identifiable {
    case off
    case auto
    case on

    var id: String { rawValue }

    /// SF Symbol icon.
    var symbol: String {
        switch self {
        case .off:  return "bolt.slash.fill"
        case .auto: return "bolt.badge.a.fill"
        case .on:   return "bolt.fill"
        }
    }

    var label: String {
        switch self {
        case .off:  return "Flash Off"
        case .auto: return "Flash Auto"
        case .on:   return "Flash On"
        }
    }

    /// Cycle to the next mode (off → auto → on → off).
    var next: FlashMode {
        switch self {
        case .off:  return .auto
        case .auto: return .on
        case .on:   return .off
        }
    }
}
