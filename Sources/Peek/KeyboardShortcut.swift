import Cocoa
import Carbon

/// Stores a keyboard shortcut as a Carbon key code + modifier flags.
/// Persisted in UserDefaults as two UInt32 values.
struct KeyboardShortcut: Equatable {

    /// Carbon virtual key code (e.g. kVK_ANSI_P = 0x23)
    let keyCode: UInt32

    /// Carbon modifier flags (e.g. optionKey | cmdKey = 0x0900)
    let carbonModifiers: UInt32

    /// The default shortcut: Option+Command+P
    static let defaultShortcut = KeyboardShortcut(
        keyCode: UInt32(kVK_ANSI_P),
        carbonModifiers: UInt32(optionKey | cmdKey)
    )

    // MARK: - Display string (e.g. "⌥⌘P")

    /// Human-readable string using standard macOS modifier symbols.
    var displayString: String {
        var parts = ""
        if carbonModifiers & UInt32(controlKey) != 0 { parts += "\u{2303}" } // ⌃
        if carbonModifiers & UInt32(optionKey)  != 0 { parts += "\u{2325}" } // ⌥
        if carbonModifiers & UInt32(shiftKey)   != 0 { parts += "\u{21E7}" } // ⇧
        if carbonModifiers & UInt32(cmdKey)     != 0 { parts += "\u{2318}" } // ⌘
        parts += keyCodeToString(keyCode)
        return parts
    }

    // MARK: - Menu item helpers

    /// Lowercase character for NSMenuItem.keyEquivalent (e.g. "p").
    /// Returns empty string for non-letter/non-digit keys.
    var keyEquivalentCharacter: String {
        return keyCodeToString(keyCode).lowercased()
    }

    /// AppKit modifier mask for NSMenuItem.keyEquivalentModifierMask.
    var appKitModifierMask: NSEvent.ModifierFlags {
        return KeyboardShortcut.carbonToAppKitModifiers(carbonModifiers)
    }

    // MARK: - Modifier conversion

    /// Convert AppKit modifier flags to Carbon modifier flags.
    static func appKitToCarbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }

    /// Convert Carbon modifier flags to AppKit modifier flags.
    static func carbonToAppKitModifiers(_ carbon: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbon & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbon & UInt32(optionKey)  != 0 { flags.insert(.option) }
        if carbon & UInt32(shiftKey)   != 0 { flags.insert(.shift) }
        if carbon & UInt32(cmdKey)     != 0 { flags.insert(.command) }
        return flags
    }

    // MARK: - Key code to display character

    private func keyCodeToString(_ code: UInt32) -> String {
        switch Int(code) {
        // Letters
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        // Digits
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        // F-keys
        case kVK_F1:  return "F1"
        case kVK_F2:  return "F2"
        case kVK_F3:  return "F3"
        case kVK_F4:  return "F4"
        case kVK_F5:  return "F5"
        case kVK_F6:  return "F6"
        case kVK_F7:  return "F7"
        case kVK_F8:  return "F8"
        case kVK_F9:  return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        // Punctuation & special
        case kVK_ANSI_Minus:        return "-"
        case kVK_ANSI_Equal:        return "="
        case kVK_ANSI_LeftBracket:  return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash:    return "\\"
        case kVK_ANSI_Semicolon:    return ";"
        case kVK_ANSI_Quote:        return "'"
        case kVK_ANSI_Comma:        return ","
        case kVK_ANSI_Period:       return "."
        case kVK_ANSI_Slash:        return "/"
        case kVK_ANSI_Grave:        return "`"
        // Navigation
        case kVK_Space:       return "\u{2423}" // ␣
        case kVK_Delete:      return "\u{232B}" // ⌫
        case kVK_ForwardDelete: return "\u{2326}" // ⌦
        case kVK_UpArrow:     return "\u{2191}" // ↑
        case kVK_DownArrow:   return "\u{2193}" // ↓
        case kVK_LeftArrow:   return "\u{2190}" // ←
        case kVK_RightArrow:  return "\u{2192}" // →
        case kVK_Home:        return "\u{2196}" // ↖
        case kVK_End:         return "\u{2198}" // ↘
        case kVK_PageUp:      return "\u{21DE}" // ⇞
        case kVK_PageDown:    return "\u{21DF}" // ⇟
        default:              return "?"
        }
    }
}
