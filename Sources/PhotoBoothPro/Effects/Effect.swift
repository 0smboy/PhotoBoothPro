import Foundation
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// User-selectable effect. Split into two disjoint kinds:
///  - `.local(LocalFilter)` — Core Image filter, applied at ~60 fps to the
///    live preview and burned into captured photos/videos.
///  - `.ai(AIStyle)`        — server-side style transfer, only runs at capture.
enum Effect: Equatable, Hashable, Identifiable {
    case local(LocalFilter)
    case ai(AIStyle)

    var id: String {
        switch self {
        case .local(let f): return "local.\(f.rawValue)"
        case .ai(let s):    return "ai.\(s.rawValue)"
        }
    }

    var displayName: String {
        switch self {
        case .local(let f): return f.displayName
        case .ai(let s):    return s.displayName
        }
    }

    var fileSuffix: String {
        switch self {
        case .local(let f): return f.rawValue
        case .ai(let s):    return s.rawValue
        }
    }

    var accentColor: Color {
        switch self {
        case .local(let f): return f.accentColor
        case .ai(let s):    return s.accentColor
        }
    }

    var isAI: Bool {
        if case .ai = self { return true }
        return false
    }

    /// The identity pass-through.
    static let normal: Effect = .local(.none)

    /// Only meaningful for `.ai`.
    var prompt: String? {
        if case .ai(let s) = self { return s.prompt }
        return nil
    }

    /// Apply the effect's CIFilter. Returns `image` unchanged for AI effects
    /// (they don't filter the live preview).
    func apply(to image: CIImage) -> CIImage {
        switch self {
        case .local(let f): return f.apply(to: image)
        case .ai:           return image
        }
    }
}

// MARK: - Local filters (Core Image)

enum LocalFilter: String, CaseIterable {
    case none
    case mono       // B&W
    case noir
    case chrome
    case sepia
    case vivid
    case thermal
    case xray
    case comic
    case invert
    case pixellate

    var displayName: String {
        switch self {
        case .none:      return "Normal"
        case .mono:      return "Mono"
        case .noir:      return "Noir"
        case .chrome:    return "Chrome"
        case .sepia:     return "Sepia"
        case .vivid:     return "Vivid"
        case .thermal:   return "Thermal"
        case .xray:      return "X-Ray"
        case .comic:     return "Comic"
        case .invert:    return "Invert"
        case .pixellate: return "Pixellate"
        }
    }

    var accentColor: Color {
        switch self {
        case .none:      return .white
        case .mono:      return Color(white: 0.8)
        case .noir:      return Color(white: 0.55)
        case .chrome:    return Color(red: 0.74, green: 0.82, blue: 0.90)
        case .sepia:     return Color(red: 0.76, green: 0.55, blue: 0.33)
        case .vivid:     return Color(red: 1.00, green: 0.45, blue: 0.30)
        case .thermal:   return Color(red: 0.98, green: 0.40, blue: 0.18)
        case .xray:      return Color(red: 0.35, green: 0.85, blue: 1.00)
        case .comic:     return Color(red: 1.00, green: 0.80, blue: 0.20)
        case .invert:    return Color(red: 0.60, green: 0.30, blue: 0.90)
        case .pixellate: return Color(red: 0.40, green: 0.70, blue: 1.00)
        }
    }

    var symbol: String {
        switch self {
        case .none:      return "circle"
        case .mono:      return "circle.lefthalf.filled"
        case .noir:      return "moon.fill"
        case .chrome:    return "rays"
        case .sepia:     return "photo.fill"
        case .vivid:     return "drop.fill"
        case .thermal:   return "thermometer"
        case .xray:      return "bolt.horizontal.fill"
        case .comic:     return "bubble.left.and.bubble.right.fill"
        case .invert:    return "circle.righthalf.filled"
        case .pixellate: return "square.grid.3x3.fill"
        }
    }

    /// Core of the pipeline. Takes a camera CIImage and returns a filtered one.
    /// Kept allocation-light; filters are recreated on each call (Core Image
    /// interns them internally).
    func apply(to image: CIImage) -> CIImage {
        switch self {
        case .none:
            return image

        case .mono:
            let f = CIFilter.photoEffectMono()
            f.inputImage = image
            return f.outputImage ?? image

        case .noir:
            let f = CIFilter.photoEffectNoir()
            f.inputImage = image
            return f.outputImage ?? image

        case .chrome:
            let f = CIFilter.photoEffectChrome()
            f.inputImage = image
            return f.outputImage ?? image

        case .sepia:
            let f = CIFilter.sepiaTone()
            f.inputImage = image
            f.intensity = 0.9
            return f.outputImage ?? image

        case .vivid:
            let f = CIFilter.colorControls()
            f.inputImage = image
            f.saturation = 1.55
            f.contrast = 1.10
            f.brightness = 0.02
            return f.outputImage ?? image

        case .thermal:
            let f = CIFilter.thermal()
            f.inputImage = image
            return f.outputImage ?? image

        case .xray:
            let f = CIFilter.xRay()
            f.inputImage = image
            return f.outputImage ?? image

        case .comic:
            let f = CIFilter.comicEffect()
            f.inputImage = image
            return f.outputImage ?? image

        case .invert:
            let f = CIFilter.colorInvert()
            f.inputImage = image
            return f.outputImage ?? image

        case .pixellate:
            let f = CIFilter.pixellate()
            f.inputImage = image
            // Scale the pixel size to the input so it reads the same across
            // preview (720p-ish) and captured photo (full res).
            let shortSide = min(image.extent.width, image.extent.height)
            f.scale = Float(max(6, shortSide / 90))
            return f.outputImage ?? image
        }
    }
}

// MARK: - AI effects

enum AIStyle: String, CaseIterable {
    case ghibli
    case anime
    case oilPainting
    case pixelArt

    var displayName: String {
        switch self {
        case .ghibli:      return "Ghibli"
        case .anime:       return "Anime"
        case .oilPainting: return "Oil Painting"
        case .pixelArt:    return "Pixel Art"
        }
    }

    var accentColor: Color {
        switch self {
        case .ghibli:      return Color(red: 0.55, green: 0.78, blue: 0.64)
        case .anime:       return Color(red: 0.96, green: 0.50, blue: 0.75)
        case .oilPainting: return Color(red: 0.82, green: 0.55, blue: 0.28)
        case .pixelArt:    return Color(red: 0.38, green: 0.70, blue: 0.98)
        }
    }

    var symbol: String {
        switch self {
        case .ghibli:      return "leaf.fill"
        case .anime:       return "sparkles"
        case .oilPainting: return "paintbrush.fill"
        case .pixelArt:    return "square.grid.4x3.fill"
        }
    }

    var prompt: String {
        switch self {
        case .ghibli:      return StylePrompts.ghibli
        case .anime:       return StylePrompts.anime
        case .oilPainting: return StylePrompts.oilPainting
        case .pixelArt:    return StylePrompts.pixelArt
        }
    }
}
