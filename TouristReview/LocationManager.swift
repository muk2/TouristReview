//
//  LocationManager.swift
//  TouristReview
//
//  Created by Mukund Chanchlani on 3/17/24.
//

import Foundation
import MapKit
import Observation


enum LocationError: LocalizedError{
    case authorizationDenied
    case authorizationRestricted
    case unknownLocation
    case accessDenied
    case network
    case operationFailed
    
    var errorDescription: String?{
        switch self{
            case .authorizationDenied:
                return NSLocalizedString("Loc access denied bruv", comment: "")
            case .authorizationRestricted:
                return NSLocalizedString("Loc access restrict m8", comment: "")
            case .unknownLocation:
                return NSLocalizedString("Where tha fook are you", comment: "")
            case .accessDenied:
                return NSLocalizedString("Access Denied", comment: "")
            case .network:
                return NSLocalizedString("Net fail", comment: "")
            case .operationFailed:
                return NSLocalizedString("Opps failed", comment: "")
        }
    }
    
    
    
}


@Observable class LocationManager: NSObject, CLLocationManagerDelegate{
    static let shared = LocationManager()
    let manager: CLLocationManager=CLLocationManager()
    var region: MKCoordinateRegion=MKCoordinateRegion()
    var error: LocationError?=nil
    
    override init(){
        super.init()
        self.manager.delegate=self
        manager.desiredAccuracy=kCLLocationAccuracyBest
    
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus{
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied:
            error = .authorizationDenied
        case .restricted:
            error = .authorizationRestricted
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locations.last.map {
            region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude), span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        if let clError=error as? CLError{
            switch clError.code{
            case .locationUnknown:
                self.error = .unknownLocation
            case .denied:
                self.error = .accessDenied
            case .network:
                self.error = .network
            default:
                self.error = .operationFailed
            }
        }
    }

}
