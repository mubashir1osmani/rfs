import Foundation

struct AppConfiguration: Sendable {
    let assistantURL: URL?
    let executeURL: URL?
    let appToken: String?
    let userID: String

    static var current: AppConfiguration {
        let environment = ProcessInfo.processInfo.environment
        return AppConfiguration(
            assistantURL: environment["NORI_ASSISTANT_URL"].flatMap(URL.init(string:)),
            executeURL: environment["NORI_EXECUTE_URL"].flatMap(URL.init(string:)),
            appToken: environment["NORI_APP_TOKEN"],
            userID: environment["NORI_USER_ID"] ?? "local-ios-user"
        )
    }
}
