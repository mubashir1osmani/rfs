import SwiftUI
import SwiftData
import CoreLocation

struct LocationPermissionView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var locationService = LocationService.shared
    @StateObject private var prayerTimeService = PrayerTimeService.shared

    @State private var isRequestingPermission = false
    @State private var permissionGranted = false
    @State private var locationObtained = false
    @State private var cityName: String?
    @State private var errorMessage: String?
    @State private var showCalculationMethodPicker = false
    @State private var selectedMethod: PrayerTimeService.CalculationMethod = .karachi

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon and title
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: "location.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                }

                Text("Location for Prayer Times")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("To provide accurate Islamic prayer times, we need access to your location. This helps us calculate prayer times based on your geographical position.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            // Status and actions
            VStack(spacing: 24) {
                if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundColor(.orange)

                        Text("Location Access Needed")
                            .font(.headline)

                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else if locationObtained, let city = cityName {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)

                        Text("Location Found")
                            .font(.headline)

                        Text("Prayer times will be calculated for \(city)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else if permissionGranted {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)

                        Text("Getting your location...")
                            .font(.headline)

                        Text("This may take a moment")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("We respect your privacy and only use your location to calculate prayer times.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            requestLocationPermission()
                        } label: {
                            if isRequestingPermission {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Allow Location Access")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(isRequestingPermission)
                        .padding(.horizontal)
                    }
                }

                // Calculation method picker
                if locationObtained {
                    VStack(spacing: 12) {
                        Text("Prayer Time Calculation Method")
                            .font(.headline)

                        Text("Choose the calculation method that best suits your region")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Menu {
                            ForEach(PrayerTimeService.CalculationMethod.allCases, id: \.self) { method in
                                Button(method.displayName) {
                                    selectedMethod = method
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedMethod.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                    }
                }

                // Continue button
                if locationObtained {
                    Button("Continue") {
                        saveLocationAndContinue()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }

            Spacer()
        }
        .padding()
        .onChange(of: locationService.authorizationStatus) { _, newStatus in
            handleAuthorizationStatusChange(newStatus)
        }
    }

    private func requestLocationPermission() {
        isRequestingPermission = true
        errorMessage = nil

        Task {
            do {
                let status = try await locationService.requestLocationPermission()
                handleAuthorizationStatusChange(status)
            } catch {
                isRequestingPermission = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleAuthorizationStatusChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            permissionGranted = true
            getLocationAndCity()
        case .denied, .restricted:
            isRequestingPermission = false
            errorMessage = "Location access is required to provide prayer times. You can enable it later in Settings."
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    private func getLocationAndCity() {
        Task {
            do {
                let location = try await locationService.getCurrentLocation()
                let placemark = try await locationService.reverseGeocode(location: location)

                await MainActor.run {
                    cityName = placemark.locality ?? placemark.administrativeArea ?? "Your Location"
                    locationObtained = true
                    isRequestingPermission = false
                }
            } catch {
                await MainActor.run {
                    isRequestingPermission = false
                    errorMessage = "Unable to get your location. Please try again."
                }
            }
        }
    }

    private func saveLocationAndContinue() {
        guard let location = locationService.currentLocation else { return }

        // Delete existing location if any
        if let existingLocation = try? modelContext.fetch(FetchDescriptor<UserLocation>()).first {
            modelContext.delete(existingLocation)
        }

        // Save new location
        let userLocation = UserLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            city: cityName,
            calculationMethod: selectedMethod.rawValue
        )

        modelContext.insert(userLocation)

        do {
            try modelContext.save()
            onComplete()
        } catch {
            errorMessage = "Failed to save location. Please try again."
        }
    }
}

#Preview {
    LocationPermissionView(onComplete: {})
}