import Foundation
import SwiftData

@MainActor
class PrayerTimeService: ObservableObject {
    static let shared = PrayerTimeService()

    @Published var isLoading = false
    @Published var error: Error?

    private let baseURL = "https://api.aladhan.com/v1"

    // Calculation methods supported by Aladhan API
    enum CalculationMethod: String, CaseIterable {
        case karachi = "KARACHI"      // University of Islamic Sciences, Karachi
        case isna = "ISNA"           // Islamic Society of North America
        case mwl = "MWL"             // Muslim World League
        case egypt = "EGYPT"         // Egyptian General Authority of Survey
        case makka = "MAKKAH"        // Umm Al-Qura University, Makkah
        case tehran = "TEHRAN"       // Institute of Geophysics, University of Tehran
        case jafari = "JAFARI"       // Shia Ithna-Ashari, Leva Institute, Qum

        var id: Int {
            switch self {
            case .karachi: return 1
            case .isna: return 2
            case .mwl: return 3
            case .egypt: return 5
            case .makka: return 4
            case .tehran: return 7
            case .jafari: return 0
            }
        }

        var displayName: String {
            switch self {
            case .karachi: return "Karachi"
            case .isna: return "ISNA"
            case .mwl: return "Muslim World League"
            case .egypt: return "Egypt"
            case .makka: return "Makkah"
            case .tehran: return "Tehran"
            case .jafari: return "Jafari"
            }
        }
    }

    private init() {}

    // MARK: - Public Methods

    func fetchPrayerTimes(for date: Date = Date(), latitude: Double, longitude: Double, method: CalculationMethod = .karachi) async throws -> PrayerTime {
        isLoading = true
        defer { isLoading = false }

        let timestamp = Int(date.timeIntervalSince1970)

        guard let url = URL(string: "\(baseURL)/timings/\(timestamp)?latitude=\(latitude)&longitude=\(longitude)&method=\(method.id)") else {
            throw PrayerTimeError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw PrayerTimeError.networkError
        }

        let decoder = JSONDecoder()
        let prayerResponse = try decoder.decode(PrayerTimingsResponse.self, from: data)

        guard prayerResponse.code == 200, prayerResponse.status == "OK" else {
            throw PrayerTimeError.apiError(prayerResponse.status)
        }

        return prayerResponse.data.timings
    }

    func getPrayerTimesForDate(_ date: Date, latitude: Double, longitude: Double, method: CalculationMethod = .karachi, context: ModelContext) async throws -> DailyPrayerTimes {
        // Check if we already have cached prayer times for this date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<DailyPrayerTimes>(
            predicate: #Predicate<DailyPrayerTimes> { prayerTime in
                prayerTime.date >= startOfDay && prayerTime.date < endOfDay
            }
        )

        // Filter the results in code for the other conditions
        if let existingPrayerTimes = try? context.fetch(descriptor).first(where: { prayerTime in
            prayerTime.latitude == latitude &&
            prayerTime.longitude == longitude &&
            prayerTime.calculationMethod == method.rawValue
        }) {
            return existingPrayerTimes
        }

        // Fetch from API
        let timings = try await fetchPrayerTimes(for: date, latitude: latitude, longitude: longitude, method: method)

        // Create and save new prayer times
        let dailyPrayerTimes = DailyPrayerTimes(
            date: startOfDay,
            timings: timings,
            method: method.rawValue,
            latitude: latitude,
            longitude: longitude
        )

        context.insert(dailyPrayerTimes)
        try context.save()

        return dailyPrayerTimes
    }

    func getPrayerTimesForWeek(starting date: Date, latitude: Double, longitude: Double, method: CalculationMethod = .karachi, context: ModelContext) async throws -> [DailyPrayerTimes] {
        var prayerTimes: [DailyPrayerTimes] = []
        let calendar = Calendar.current

        for dayOffset in 0..<7 {
            let currentDate = calendar.date(byAdding: .day, value: dayOffset, to: date)!
            let dailyPrayerTimes = try await getPrayerTimesForDate(currentDate, latitude: latitude, longitude: longitude, method: method, context: context)
            prayerTimes.append(dailyPrayerTimes)
        }

        return prayerTimes
    }

    func getNextPrayerTime(from currentDate: Date = Date(), latitude: Double, longitude: Double, method: CalculationMethod = .karachi, context: ModelContext) async throws -> (prayerName: String, time: Date)? {
        let todayPrayers = try await getPrayerTimesForDate(currentDate, latitude: latitude, longitude: longitude, method: method, context: context)

        let prayerTimes = [
            ("Fajr", todayPrayers.fajr),
            ("Dhuhr", todayPrayers.dhuhr),
            ("Asr", todayPrayers.asr),
            ("Maghrib", todayPrayers.maghrib),
            ("Isha", todayPrayers.isha)
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"

        let calendar = Calendar.current
        let now = Date()

        for (name, timeString) in prayerTimes {
            if let prayerTime = dateFormatter.date(from: timeString) {
                // Create today's prayer time
                let todayPrayerTime = calendar.date(bySettingHour: calendar.component(.hour, from: prayerTime),
                                                  minute: calendar.component(.minute, from: prayerTime),
                                                  second: 0,
                                                  of: currentDate)!

                if todayPrayerTime > now {
                    return (name, todayPrayerTime)
                }
            }
        }

        // If no prayer today, get tomorrow's Fajr
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        let tomorrowPrayers = try await getPrayerTimesForDate(tomorrow, latitude: latitude, longitude: longitude, method: method, context: context)

        if let fajrTime = dateFormatter.date(from: tomorrowPrayers.fajr) {
            let tomorrowFajr = calendar.date(bySettingHour: calendar.component(.hour, from: fajrTime),
                                           minute: calendar.component(.minute, from: fajrTime),
                                           second: 0,
                                           of: tomorrow)!
            return ("Fajr", tomorrowFajr)
        }

        return nil
    }

    func formatPrayerTime(_ timeString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"

        if let date = dateFormatter.date(from: timeString) {
            dateFormatter.dateFormat = "h:mm a"
            return dateFormatter.string(from: date)
        }

        return timeString
    }
}

// MARK: - Errors

enum PrayerTimeError: LocalizedError {
    case invalidURL
    case networkError
    case apiError(String)
    case decodingError
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError:
            return "Network error occurred while fetching prayer times"
        case .apiError(let message):
            return "API error: \(message)"
        case .decodingError:
            return "Failed to decode prayer times data"
        case .noData:
            return "No prayer times data available"
        }
    }
}