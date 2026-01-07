//
//  WeatherService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Fetches weather data for hydration goal adjustments
//

import Foundation
import CoreLocation

// MARK: - Weather Service Protocol

protocol WeatherServiceProtocol {
    func fetchCurrentTemperature() async -> Double?
    func getLastKnownTemperature() -> Double?
}

// MARK: - Weather Data Model

struct WeatherData: Codable {
    let temperature: Double
    let humidity: Int
    let description: String
    let fetchedAt: Date
    
    var isExpired: Bool {
        // Cache expires after 1 hour
        Date().timeIntervalSince(fetchedAt) > 3600
    }
}

// MARK: - Weather Service Implementation

final class WeatherService: NSObject, WeatherServiceProtocol {
    
    static let shared = WeatherService()
    
    private let locationManager = CLLocationManager()
    private var cachedWeather: WeatherData?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    
    // Using OpenWeatherMap free tier API
    // Note: In production, move this to server-side or use environment variables
    private let apiKey = "YOUR_OPENWEATHERMAP_API_KEY"
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    // MARK: - Public Methods
    
    /// Fetches current temperature in Celsius
    func fetchCurrentTemperature() async -> Double? {
        // Return cached value if still valid
        if let cached = cachedWeather, !cached.isExpired {
            return cached.temperature
        }
        
        // Try to get location
        guard let location = await requestLocation() else {
            // Fall back to default warm climate for India
            return 28.0
        }
        
        // Fetch weather from API
        do {
            let weather = try await fetchWeather(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            cachedWeather = weather
            return weather.temperature
        } catch {
            print("⛅️ WeatherService: Failed to fetch weather - \(error.localizedDescription)")
            // Return default temperature for India
            return 28.0
        }
    }
    
    /// Returns last known temperature without network call
    func getLastKnownTemperature() -> Double? {
        cachedWeather?.temperature
    }
    
    // MARK: - Private Methods
    
    private func requestLocation() async -> CLLocation? {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // Wait a bit for authorization
            try? await Task.sleep(nanoseconds: 500_000_000)
            return await getCurrentLocation()
            
        case .authorizedWhenInUse, .authorizedAlways:
            return await getCurrentLocation()
            
        case .denied, .restricted:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    private func getCurrentLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
            
            // Timeout after 10 seconds
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if self.locationContinuation != nil {
                    self.locationContinuation?.resume(returning: nil)
                    self.locationContinuation = nil
                }
            }
        }
    }
    
    private func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "metric") // Celsius
        ]
        
        guard let url = components.url else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WeatherError.networkError
        }
        
        let decoded = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
        
        return WeatherData(
            temperature: decoded.main.temp,
            humidity: decoded.main.humidity,
            description: decoded.weather.first?.description ?? "Unknown",
            fetchedAt: Date()
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationContinuation?.resume(returning: locations.first)
        locationContinuation = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⛅️ WeatherService: Location error - \(error.localizedDescription)")
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}

// MARK: - OpenWeatherMap Response Models

private struct OpenWeatherResponse: Codable {
    let main: MainData
    let weather: [WeatherDescription]
    
    struct MainData: Codable {
        let temp: Double
        let humidity: Int
    }
    
    struct WeatherDescription: Codable {
        let description: String
    }
}

// MARK: - Weather Errors

enum WeatherError: LocalizedError {
    case invalidURL
    case networkError
    case decodingError
    case locationDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid weather API URL"
        case .networkError: return "Failed to fetch weather data"
        case .decodingError: return "Failed to decode weather response"
        case .locationDenied: return "Location access denied"
        }
    }
}
