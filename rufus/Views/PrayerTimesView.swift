import SwiftUI
import SwiftData

struct PrayerTimesView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var prayerTimeService = PrayerTimeService.shared
    @StateObject private var locationService = LocationService.shared

    @Query private var userLocations: [UserLocation]
    @State private var todayPrayers: DailyPrayerTimes?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let prayerNames = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
    private let prayerIcons = ["moon.stars", "sun.max", "sunset", "sunset.fill", "moon"]

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Prayer Times")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)

            if isLoading {
                ProgressView("Loading prayer times...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Unable to load prayer times")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task {
                            await loadPrayerTimes()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let prayers = todayPrayers {
                VStack(spacing: 16) {
                    // Location info
                    if let userLocation = userLocations.first,
                       let city = userLocation.city {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.secondary)
                            Text(city)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Prayer times grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(Array(zip(prayerNames.indices, prayerNames)), id: \.0) { index, name in
                            PrayerTimeCard(
                                name: name,
                                time: getPrayerTime(for: name, from: prayers),
                                icon: prayerIcons[index],
                                isNextPrayer: isNextPrayer(name, from: prayers)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "location.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Location not set")
                        .font(.headline)
                    Text("Please set your location to view prayer times")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await loadPrayerTimes()
        }
        .refreshable {
            await loadPrayerTimes()
        }
    }

    private func loadPrayerTimes() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let userLocation = userLocations.first else {
                errorMessage = "Please set your location first"
                return
            }

            let method = PrayerTimeService.CalculationMethod(rawValue: userLocation.calculationMethod) ?? .karachi
            todayPrayers = try await prayerTimeService.getPrayerTimesForDate(
                Date(),
                latitude: userLocation.latitude,
                longitude: userLocation.longitude,
                method: method,
                context: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func getPrayerTime(for prayerName: String, from prayers: DailyPrayerTimes) -> String {
        switch prayerName {
        case "Fajr": return prayerTimeService.formatPrayerTime(prayers.fajr)
        case "Dhuhr": return prayerTimeService.formatPrayerTime(prayers.dhuhr)
        case "Asr": return prayerTimeService.formatPrayerTime(prayers.asr)
        case "Maghrib": return prayerTimeService.formatPrayerTime(prayers.maghrib)
        case "Isha": return prayerTimeService.formatPrayerTime(prayers.isha)
        default: return ""
        }
    }

    private func isNextPrayer(_ prayerName: String, from prayers: DailyPrayerTimes) -> Bool {
        // This would need more complex logic to determine the next prayer
        // For now, just highlight Fajr as an example
        return prayerName == "Fajr"
    }
}

struct PrayerTimeCard: View {
    let name: String
    let time: String
    let icon: String
    let isNextPrayer: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isNextPrayer ? .blue : .secondary)

            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(time)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(isNextPrayer ? .blue : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isNextPrayer ? Color.blue.opacity(0.1) : Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isNextPrayer ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    PrayerTimesView()
}