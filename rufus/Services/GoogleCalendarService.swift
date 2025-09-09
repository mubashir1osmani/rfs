import Foundation
import GoogleSignIn
import UIKit

class GoogleCalendarService: ObservableObject {
    private let baseURL = "https://www.googleapis.com/calendar/v3"
    
    enum GoogleCalendarError: Error {
        case notSignedIn
        case noAccessToken
        case apiError(String)
        case parseError
        case networkError(Error)
        
        var localizedDescription: String {
            switch self {
            case .notSignedIn:
                return "User is not signed in to Google"
            case .noAccessToken:
                return "No access token available"
            case .apiError(let message):
                return "API Error: \(message)"
            case .parseError:
                return "Failed to parse calendar data"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchGoogleCalendarEvents(from startDate: Date, to endDate: Date) async throws -> [[String: Any]] {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw GoogleCalendarError.notSignedIn
        }
        
        let accessToken = user.accessToken.tokenString
        
        let dateFormatter = ISO8601DateFormatter()
        let timeMin = dateFormatter.string(from: startDate)
        let timeMax = dateFormatter.string(from: endDate)
        
        let urlString = "\(baseURL)/calendars/primary/events?timeMin=\(timeMin)&timeMax=\(timeMax)&singleEvents=true&orderBy=startTime"
        
        guard let url = URL(string: urlString) else {
            throw GoogleCalendarError.apiError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw GoogleCalendarError.apiError("Status: \(httpResponse.statusCode), \(errorMessage)")
                }
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                throw GoogleCalendarError.parseError
            }
            
            return items
        } catch {
            if error is GoogleCalendarError {
                throw error
            } else {
                throw GoogleCalendarError.networkError(error)
            }
        }
    }
    
    func requestCalendarScopes() async throws {
        guard let presentingViewController = await MainActor.run(body: {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                return window.rootViewController
            }
            return nil
        }) else {
            throw GoogleCalendarError.apiError("No presenting view controller")
        }
        
        let additionalScopes = ["https://www.googleapis.com/auth/calendar.readonly"]
        
        do {
            _ = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController, hint: nil, additionalScopes: additionalScopes)
        } catch {
            throw GoogleCalendarError.networkError(error)
        }
    }
    
    private func parseGoogleDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
}
