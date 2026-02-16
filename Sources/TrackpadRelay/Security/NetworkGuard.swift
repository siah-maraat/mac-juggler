import Foundation

struct NetworkGuard {
    /// Returns true if the IP address is in a private/local range.
    static func isLocalNetwork(_ ip: String) -> Bool {
        // IPv4 private ranges
        if ip.hasPrefix("192.168.") { return true }
        if ip.hasPrefix("10.") { return true }
        if ip.hasPrefix("172.") {
            let parts = ip.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]) {
                if second >= 16 && second <= 31 { return true }
            }
        }

        // Loopback
        if ip == "127.0.0.1" || ip == "::1" { return true }

        // IPv6 link-local
        if ip.hasPrefix("fe80:") { return true }

        // IPv6 unique local
        if ip.hasPrefix("fd") || ip.hasPrefix("fc") { return true }

        return false
    }
}
