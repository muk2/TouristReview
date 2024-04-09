//
//  MapSearch.swift
//  TouristReview
//
//  Created by Mukund Chanchlani on 3/22/24.
//

import Foundation
import MapKit





func makeCall(phone: String){
    if let url = URL(string: "tel://\(phone)"){
        if UIApplication.shared.canOpenURL(url){
            UIApplication.shared.open(url)
            
        }else{
            print("device can't make phone call")
        }
    }
}


func calculateDirection(from: MKMapItem, to: MKMapItem)async->MKRoute?{
    
    let directionRequest = MKDirections.Request()
    directionRequest.transportType = .automobile
    directionRequest.source = from
    directionRequest.destination = to
    
    let directions = MKDirections(request: directionRequest)
    let response = try? await directions.calculate()
    return response?.routes.first
}

func calculateDistance(from: CLLocation, to: CLLocation)->Measurement<UnitLength>{
    let distanceInMiles=from.distance(from: to)
    return Measurement(value: distanceInMiles, unit: .meters)
}

func performSearch(searchTerm: String, visibleRegion: MKCoordinateRegion?) async throws -> [MKMapItem]{
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = searchTerm
    request.resultTypes = .pointOfInterest
    
    guard let region = visibleRegion else{return [] }
    request.region = region
    
    let search = MKLocalSearch(request: request)
    let response = try await search.start()
    
    return response.mapItems

}
