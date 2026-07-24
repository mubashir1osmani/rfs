import AuthenticationServices
import CryptoKit
import EventKit
import Foundation
import Security
import UIKit

enum IntegrationError: LocalizedError {
    case actionFailed(String)
    case calendarAccessDenied
    case googleNotConfigured
    case missingEmailRecipient
    case oauthFailed

    var errorDescription: String? {
        switch self {
        case let .actionFailed(message): message
        case .calendarAccessDenied: "Allow Calendar access in Settings to add this event."
        case .googleNotConfigured: "Add your Google iOS OAuth client ID and redirect scheme in the Nori build settings."
        case .missingEmailRecipient: "Add a recipient before sending this email."
        case .oauthFailed: "Google sign-in could not be completed."
        }
    }
}

@MainActor
final class GoogleOAuthService: NSObject, ObservableObject {
    static let shared = GoogleOAuthService()

    @Published private(set) var isConnected = CredentialStore.googleCredentials != nil
    @Published private(set) var isConnecting = false

    private struct Credentials: Codable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let expiresIn: Double
        let refreshToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
        }
    }

    private let configuration: AppConfiguration
    private var authenticationSession: ASWebAuthenticationSession?

    init(configuration: AppConfiguration = .current) {
        self.configuration = configuration
        super.init()
    }

    func connect() async throws {
        guard let clientID = configuration.googleClientID,
              let redirectScheme = configuration.googleRedirectScheme else {
            throw IntegrationError.googleNotConfigured
        }
        isConnecting = true
        defer { isConnecting = false }

        let verifier = Self.randomVerifier()
        let state = Self.randomVerifier()
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let redirectURI = "\(redirectScheme):/oauthredirect"
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/gmail.send"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        guard let authorizationURL = components?.url else { throw IntegrationError.oauthFailed }
        let callbackURL = try await authenticate(url: authorizationURL, callbackScheme: redirectScheme)
        guard let callback = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              callback.queryItems?.first(where: { $0.name == "state" })?.value == state,
              let code = callback.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw IntegrationError.oauthFailed
        }
        let token = try await exchangeCode(code, verifier: verifier, redirectURI: redirectURI, clientID: clientID)
        let credentials = Credentials(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken ?? loadCredentials()?.refreshToken ?? "",
            expiresAt: Date().addingTimeInterval(token.expiresIn)
        )
        guard !credentials.refreshToken.isEmpty else { throw IntegrationError.oauthFailed }
        try save(credentials)
        isConnected = true
    }

    func disconnect() throws {
        try CredentialStore.setGoogleCredentials(nil)
        isConnected = false
    }

    func validAccessToken() async throws -> String {
        guard var credentials = loadCredentials() else { throw IntegrationError.oauthFailed }
        if credentials.expiresAt > Date().addingTimeInterval(60) { return credentials.accessToken }
        guard let clientID = configuration.googleClientID else { throw IntegrationError.googleNotConfigured }
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "refresh_token", value: credentials.refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token"),
        ]
        let response: TokenResponse = try await tokenRequest(components.percentEncodedQuery ?? "")
        credentials.accessToken = response.accessToken
        credentials.expiresAt = Date().addingTimeInterval(response.expiresIn)
        try save(credentials)
        return credentials.accessToken
    }

    private func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let callbackURL { continuation.resume(returning: callbackURL) }
                else { continuation.resume(throwing: error ?? IntegrationError.oauthFailed) }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            authenticationSession = session
            guard session.start() else {
                continuation.resume(throwing: IntegrationError.oauthFailed)
                return
            }
        }
    }

    private func exchangeCode(_ code: String, verifier: String, redirectURI: String, clientID: String) async throws -> TokenResponse {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
        ]
        return try await tokenRequest(components.percentEncodedQuery ?? "")
    }

    private func tokenRequest(_ body: String) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw IntegrationError.oauthFailed
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func loadCredentials() -> Credentials? {
        guard let data = CredentialStore.googleCredentials else { return nil }
        return try? JSONDecoder().decode(Credentials.self, from: data)
    }

    private func save(_ credentials: Credentials) throws {
        try CredentialStore.setGoogleCredentials(JSONEncoder().encode(credentials))
    }

    private static func randomVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension GoogleOAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? UIWindow(frame: .zero)
    }
}

@MainActor
final class IntegrationService {
    private let eventStore = EKEventStore()
    private let google = GoogleOAuthService.shared

    func execute(_ action: AssistantAction) async throws {
        switch action.kind {
        case .calendar, .meeting:
            if google.isConnected { try await addToGoogleCalendar(action) }
            else { try await addToSystemCalendar(action) }
        case .email:
            if google.isConnected { try await sendWithGmail(action) }
            else { try openMailDraft(action) }
        case .task:
            return
        }
    }

    private func addToGoogleCalendar(_ action: AssistantAction) async throws {
        let token = try await google.validAccessToken()
        let start = action.startDate
        let end = start.addingTimeInterval(TimeInterval((action.durationMinutes ?? 60) * 60))
        let body: [String: Any] = [
            "summary": action.title ?? "Focus block",
            "description": action.notes ?? "Planned with Nori",
            "start": ["dateTime": start.ISO8601Format()],
            "end": ["dateTime": end.ISO8601Format()],
            "attendees": (action.attendees ?? []).map { ["email": $0] },
        ]
        try await googleRequest(
            url: URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events?sendUpdates=all")!,
            token: token,
            body: body
        )
    }

    private func sendWithGmail(_ action: AssistantAction) async throws {
        guard let recipient = action.to, !recipient.isEmpty else { throw IntegrationError.missingEmailRecipient }
        let token = try await google.validAccessToken()
        let message = [
            "To: \(recipient)",
            "Subject: \(action.subject ?? "Quick follow-up")",
            "MIME-Version: 1.0",
            "Content-Type: text/plain; charset=UTF-8",
            "",
            action.body ?? "",
        ].joined(separator: "\r\n")
        let raw = Data(message.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        try await googleRequest(
            url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send")!,
            token: token,
            body: ["raw": raw]
        )
    }

    private func googleRequest(url: URL, token: String, body: [String: Any]) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let error = payload?["error"] as? [String: Any]
            throw IntegrationError.actionFailed(error?["message"] as? String ?? "Google could not complete that action.")
        }
    }

    private func addToSystemCalendar(_ action: AssistantAction) async throws {
        let hasAccess = try await eventStore.requestFullAccessToEvents()
        guard hasAccess, let calendar = eventStore.defaultCalendarForNewEvents else {
            throw IntegrationError.calendarAccessDenied
        }
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = action.title ?? (action.kind == .meeting ? "Meeting" : "Focus block")
        event.startDate = action.startDate
        event.endDate = action.startDate.addingTimeInterval(TimeInterval((action.durationMinutes ?? 60) * 60))
        event.notes = action.notes ?? "Planned with Nori"
        event.url = URL(string: "nori://action/\(action.id)")
        try eventStore.save(event, span: .thisEvent, commit: true)
    }

    private func openMailDraft(_ action: AssistantAction) throws {
        guard let recipient = action.to, !recipient.isEmpty else { throw IntegrationError.missingEmailRecipient }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: action.subject ?? "Quick follow-up"),
            URLQueryItem(name: "body", value: action.body ?? ""),
        ]
        guard let url = components.url else { throw IntegrationError.actionFailed("Nori couldn’t open this email draft.") }
        UIApplication.shared.open(url)
    }
}
