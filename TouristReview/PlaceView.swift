//
//  PlaceView.swift
//  TouristReview
//
//  Created by Mukund Chanchlani on 3/22/24.
//

import Foundation
import MapKit
import SwiftUI

struct PlaceView: View {
    
    let mapItem: MKMapItem
    
    private var address: String{
        let placemark = mapItem.placemark
        let address = "\(placemark.thoroughfare ?? "") \(placemark.subThoroughfare ?? ""), \(placemark.locality ?? ""), \(placemark.administrativeArea ?? "") \(placemark.postalCode ?? ""), \(placemark.country ?? "")"
        return address

    }
    private var distance: Measurement<UnitLength>? {
        guard let userLocation = LocationManager.shared.manager.location,
              let destinationLocation = mapItem.placemark.location
        else{
            return nil
        }
        
        return calculateDistance(from: userLocation, to: destinationLocation)
    }
    
    var body: some View {
        VStack(alignment: .leading){
            Text(mapItem.name ?? "")
                .font(.title3)
            Text(address)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let distance {
                Text(distance, formatter: MeasurementFormatter.distance)
            }
        }
        
    }
}
