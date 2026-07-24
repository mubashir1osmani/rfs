import Foundation

struct AppConfiguration: Sendable {
    let assistantURL: URL?
    let executeURL: URL?
    private let developmentAppToken: String?
    let userID: String

    var usesRemoteAssistant: Bool { assistantURL != nil }
    var usesRemoteExecution: Bool { executeURL != nil }
    var appToken: String? { developmentAppToken ?? CredentialStore.appToken() }
    var hasAppToken: Bool { appToken != nil }

    init(assistantURL: URL?, executeURL: URL?, appToken: String?, userID: String) {
        self.assistantURL = assistantURL
        self.executeURL = executeURL
        developmentAppToken = appToken
        self.userID = userID
    }

    static var current: AppConfiguration {
        let environment = ProcessInfo.processInfo.environment
        return AppConfiguration(
            assistantURL: configuredURL(environment["NORI_ASSISTANT_URL"], plistKey: "NORIAssistantURL"),
            executeURL: configuredURL(environment["NORI_EXECUTE_URL"], plistKey: "NORIExecuteURL"),
            appToken: clean(environment["NORI_APP_TOKEN"]),
            userID: environment["NORI_USER_ID"] ?? "local-ios-user"
        )
    }

    private static func configuredURL(_ environmentValue: String?, plistKey: String) -> URL? {
        let bundledValue = Bundle.main.object(forInfoDictionaryKey: plistKey) as? String
        guard let value = clean(environmentValue) ?? clean(bundledValue),
              let url = URL(string: value),
              ["https", "http"].contains(url.scheme?.lowercased()) else { return nil }
        return url
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}
