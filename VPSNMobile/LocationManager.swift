

import CoreLocation

protocol LocationManagering {
    func attemptLocationAccess()
    func canGetCorrectGPS() -> Bool
    func getLocation() -> CLLocation?
}

final class LocationManager: NSObject {
    private let locationManager = CLLocationManager()
    
    required override init() {
        super.init()
        locationManager.delegate = self
    }
}

extension LocationManager: LocationManagering {
    func getLocation() -> CLLocation? {
        return locationManager.location
    }
    
    func attemptLocationAccess() {
        guard CLLocationManager.locationServicesEnabled() else {
            return
        }
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            if #available(iOS 14.0, *) {
                if locationManager.accuracyAuthorization == .reducedAccuracy {
                    locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "TemporaryAuth") { (err) in
                        if err == nil {
                            self.locationManager.startUpdatingLocation()
                            self.locationManager.startUpdatingHeading()
                        }
                    }
                    return
                }
            }
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
            
        default:
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func canGetCorrectGPS() -> Bool {
        if #available(iOS 14.0, *) {
            let authStatus = locationManager.authorizationStatus
            let accAuth = locationManager.accuracyAuthorization
            return authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse && accAuth == .fullAccuracy
        } else {
            let authStatus = CLLocationManager.authorizationStatus()
            return authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations
    locations: [CLLocation]) {
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if #available(iOS 14.0, *) {
                if locationManager.accuracyAuthorization == .reducedAccuracy {
                    locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "TemporaryAuth") { (err) in
                        if err == nil {
                            self.locationManager.startUpdatingLocation()
                            self.locationManager.startUpdatingHeading()
                        }
                    }
                    return
                }
            }
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        default:
            locationManager.stopUpdatingLocation()
            locationManager.stopUpdatingHeading()
        }
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
    }
}
