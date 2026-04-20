import Foundation
import SwiftUI

enum Effect: String, CaseIterable, Identifiable, Hashable {
    case normal
    case ghibli
    case anime
    case oilPainting
    case pixelArt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal:      return "Normal"
        case .ghibli:      return "Ghibli"
        case .anime:       return "Anime"
        case .oilPainting: return "Oil Painting"
        case .pixelArt:    return "Pixel Art"
        }
    }

    var isAI: Bool { self != .normal }

    var prompt: String? {
        switch self {
        case .normal:      return nil
        case .ghibli:      return StylePrompts.ghibli
        case .anime:       return StylePrompts.anime
        case .oilPainting: return StylePrompts.oilPainting
        case .pixelArt:    return StylePrompts.pixelArt
        }
    }

    var accentColor: Color {
        switch self {
        case .normal:      return .white
        case .ghibli:      return Color(red: 0.55, green: 0.78, blue: 0.64)
        case .anime:       return Color(red: 0.96, green: 0.50, blue: 0.75)
        case .oilPainting: return Color(red: 0.82, green: 0.55, blue: 0.28)
        case .pixelArt:    return Color(red: 0.38, green: 0.70, blue: 0.98)
        }
    }

    var fileSuffix: String {
        switch self {
        case .normal:      return "normal"
        case .ghibli:      return "ghibli"
        case .anime:       return "anime"
        case .oilPainting: return "oil"
        case .pixelArt:    return "pixel"
        }
    }
}
