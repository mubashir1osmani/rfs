//
//  GoogleCalendarService.swift
//  rufus
//
//  Created by AI Assistant
//

import Foundation
import GoogleSignIn

class GoogleCalendarService {
    func fetchGoogleCalendarEvents(from startDate: Date, to endDate: Date) async throws -> [[String: Any]] {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            return []
        }

        // Get the access token
        let accessToken = user.accessToken.tokenString

        let dateFormatter = ISO8601DateFormatter()
        let timeMin = dateFormatter.string(from: startDate)
        let timeMax = dateFormatter.string(from: endDate)

        var urlComponents = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        urlComponents.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMin),
            URLQueryItem(name: "timeMax", value: timeMax),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        guard let url = urlComponents.url else {
            throw NSError(domain: "GoogleCalendarService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "GoogleCalendarService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch events"])
        }

        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        return json?["items"] as? [[String: Any]] ?? []
    }
}
