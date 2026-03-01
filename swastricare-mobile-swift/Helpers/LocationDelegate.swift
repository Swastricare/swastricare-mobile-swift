//
//  LocationDelegate.swift
//  swastricare-mobile-swift
//
//  CLLocationManager delegate for onboarding location requests
//

import Foundation
import CoreLocation

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    let onAuthorizationChange: (CLAuthorizationStatus) -> Void
    let onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?

    init(
        onAuthorizationChange: @escaping (CLAuthorizationStatus) -> Void,
        onLocationUpdate: ((CLLocationCoordinate2D) -> Void)? = nil
    ) {
        self.onAuthorizationChange = onAuthorizationChange
        self.onLocationUpdate = onLocationUpdate
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            onLocationUpdate?(location.coordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
