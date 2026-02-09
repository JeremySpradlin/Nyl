//
//  WeatherService.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/5/26.
//

import Foundation
import WeatherKit
import CoreLocation
import Combine

/// Service that manages weather data fetching
@MainActor
class WeatherService: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var temperature: Double = 0.0
    @Published var condition: String = "Unknown"
    @Published var location: String = "Locating..."
    @Published var lastUpdated: Date?
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // MARK: - Private Properties
    
    private let weatherKit = WeatherKit.WeatherService.shared
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    
    // MARK: - Dependencies
    
    weak var serverService: ServerService?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    // MARK: - Public Methods
    
    /// Request location authorization and fetch weather
    func requestLocationAndFetchWeather() {
        let authStatus = locationManager.authorizationStatus
        
        switch authStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            error = "Location access denied"
            location = "Location Unavailable"
        @unknown default:
            error = "Unknown location authorization status"
        }
    }
    
    /// Fetch weather for current location
    func fetchWeather() async {
        guard let location = currentLocation else {
            requestLocationAndFetchWeather()
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let weather = try await weatherKit.weather(for: location)
            
            // Update UI with weather data (convert to Fahrenheit)
            temperature = weather.currentWeather.temperature.converted(to: .fahrenheit).value
            
            // Get condition description
            condition = weather.currentWeather.condition.description
            
            lastUpdated = Date()
            
            // Reverse geocode to get location name
            await updateLocationName(for: location)
            
            // Notify WebSocket clients about weather update
            await serverService?.broadcastStatusUpdate()
            
        } catch {
            self.error = "Failed to fetch weather: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func updateLocationName(for location: CLLocation) async {
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                if let city = placemark.locality, let state = placemark.administrativeArea {
                    self.location = "\(city), \(state)"
                } else if let city = placemark.locality {
                    self.location = city
                } else {
                    self.location = "Current Location"
                }
            }
        } catch {
            self.location = "Current Location"
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            #if os(macOS)
            if status == .authorizedAlways {
                manager.requestLocation()
            }
            #else
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                manager.requestLocation()
            }
            #endif
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.first else { return }
            currentLocation = location
            await fetchWeather()
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = "Location error: \(error.localizedDescription)"
            location = "Location Error"
        }
    }
}
