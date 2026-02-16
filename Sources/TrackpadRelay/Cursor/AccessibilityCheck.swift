import ApplicationServices
import Foundation

struct AccessibilityCheck {
    static func ensurePermission() -> Bool {
        let trusted = AXIsProcessTrusted()

        if !trusted {
            fputs("⚠️  Accessibility permission required.\n", stderr)
            fputs("   Open System Settings > Privacy & Security > Accessibility\n", stderr)
            fputs("   and enable trackpad-relay.\n\n", stderr)
            fputs("   Then restart the service:\n", stderr)
            fputs("     brew services restart trackpad-relay\n", stderr)
        }

        return trusted
    }

    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }
}
