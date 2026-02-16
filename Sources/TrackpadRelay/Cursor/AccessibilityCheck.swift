import ApplicationServices
import Foundation

struct AccessibilityCheck {
    static func ensurePermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            print("⚠️  Accessibility permission required.")
            print("   Open System Settings > Privacy & Security > Accessibility")
            print("   and enable trackpad-relay.")
            print("")
            print("   Then restart the service:")
            print("     brew services restart trackpad-relay")
        }

        return trusted
    }

    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }
}
