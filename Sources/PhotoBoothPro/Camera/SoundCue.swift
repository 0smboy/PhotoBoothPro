import Foundation
import AppKit

/// Lightweight wrapper around built-in macOS system sounds so the countdown
/// can beep without us shipping audio assets.
enum SoundCue {
    /// Countdown tick ("3", "2", "1"). Short, high-pitched.
    case tick
    /// The actual capture — classic camera shutter click.
    case shutter

    /// macOS has `Tink`, `Pop`, `Glass`, `Ping`, `Frog`, `Funk`, `Basso`,
    /// `Blow`, `Bottle`, `Hero`, `Morse`, `Purr`, `Sosumi`, `Submarine`.
    /// Best fit without shipping assets:
    ///   tick     → Tink (clean, short, "1"-ish)
    ///   shutter  → Grab (screenshot shutter click, pre-installed)
    private var systemSoundName: NSSound.Name? {
        switch self {
        case .tick:    return NSSound.Name("Tink")
        case .shutter: return NSSound.Name("Grab")
        }
    }

    private var fallbackSoundFilePaths: [String] {
        switch self {
        case .tick:
            return ["/System/Library/Sounds/Tink.aiff"]
        case .shutter:
            return [
                "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Grab.aif",
                "/System/Library/Sounds/Glass.aiff"
            ]
        }
    }

    /// Fire-and-forget. Non-blocking; safe to call from any actor.
    func play() {
        // Try the named lookup first (covers the normal case).
        if let name = systemSoundName, let sound = NSSound(named: name) {
            sound.play()
            return
        }
        // Fall back to a direct file load so a missing named sound doesn't
        // leave us silent.
        for path in fallbackSoundFilePaths {
            if let s = NSSound(contentsOfFile: path, byReference: true) {
                s.play()
                return
            }
        }
    }
}
