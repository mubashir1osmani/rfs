import Foundation

struct AppConfiguration: Sendable {
    private let developmentOpenAIKey: String?
    let googleClientID: String?
    let googleRedirectScheme: String?
    let userID: String

    var usesRemoteAssistant: Bool { openAIKey != nil }
    var openAIKey: String? { developmentOpenAIKey ?? CredentialStore.openAIKey }
    var hasOpenAIKey: Bool { openAIKey != nil }
    var chatCompletionsURL: URL { Self.openAIBaseURL.appending(path: "v1/chat/completions") }
    var realtimeClientSecretsURL: URL { Self.openAIBaseURL.appending(path: "v1/realtime/client_secrets") }
    var realtimeCallsURL: URL { Self.openAIBaseURL.appending(path: "v1/realtime/calls") }

    init(
        openAIKey: String?,
        googleClientID: String?,
        googleRedirectScheme: String?,
        userID: String
    ) {
        developmentOpenAIKey = openAIKey
        self.googleClientID = googleClientID
        self.googleRedirectScheme = googleRedirectScheme
        self.userID = userID
    }

    static var current: AppConfiguration {
        let environment = ProcessInfo.processInfo.environment
        return AppConfiguration(
            openAIKey: clean(environment["NORI_OPENAI_API_KEY"]),
            googleClientID: clean(environment["NORI_GOOGLE_CLIENT_ID"] ?? bundledValue(for: "NORIGoogleClientID")),
            googleRedirectScheme: clean(environment["NORI_GOOGLE_REDIRECT_SCHEME"] ?? bundledValue(for: "NORIGoogleRedirectScheme")),
            userID: environment["NORI_USER_ID"] ?? "local-ios-user"
        )
    }

    private static let openAIBaseURL = URL(string: "https://api.openai.com/")!

    private static func bundledValue(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}
