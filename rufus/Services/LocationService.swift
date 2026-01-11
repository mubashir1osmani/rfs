import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isLoading = false

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // Good enough for prayer times
        locationManager.distanceFilter = 1000 // Update every 1km
    }

    // MARK: - Public Methods

    func requestLocationPermission() async throws -> CLAuthorizationStatus {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            return try await requestPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            return status
        case .denied, .restricted:
            throw LocationError.permissionDenied
        @unknown default:
            throw LocationError.unknown
        }
    }

    func getCurrentLocation() async throws -> CLLocation {
        try await requestLocationPermission()

        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    func reverseGeocode(location: CLLocation) async throws -> CLPlacemark {
        let geocoder = CLGeocoder()

        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else {
            throw LocationError.geocodingFailed
        }

        return placemark
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            self.currentLocation = location
            self.locationContinuation?.resume(returning: location)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationContinuation?.resume(throwing: error)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }

    // MARK: - Private Methods

    private func requestPermission() async throws -> CLAuthorizationStatus {
        return try await withCheckedThrowingContinuation { continuation in
            // Request when in use permission
            locationManager.requestWhenInUseAuthorization()

            // Wait for authorization change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let status = self.locationManager.authorizationStatus
                continuation.resume(returning: status)
            }
        }
    }
}

// MARK: - Errors

enum LocationError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case geocodingFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission denied. Please enable location services in Settings."
        case .locationUnavailable:
            return "Unable to determine your location. Please check your location settings."
        case .geocodingFailed:
            return "Unable to determine your location details."
        case .unknown:
            return "An unknown location error occurred."
        }
    }
}