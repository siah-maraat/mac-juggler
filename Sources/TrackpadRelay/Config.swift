import Foundation

struct AppConfig {
    var port: Int
    var host: String
    var authToken: String?
    var maxEventsPerSecond: Int
    var verbose: Bool

    static let `default` = AppConfig(
        port: 8080,
        host: "0.0.0.0",
        authToken: nil,
        maxEventsPerSecond: 1000,
        verbose: false
    )
}
