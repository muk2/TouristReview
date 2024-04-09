//
//  PlaceListView.swift
//  TouristReview
//
//  Created by Mukund Chanchlani on 3/23/24.
//

import SwiftUI
import MapKit

struct PlaceListView: View {
    
    let mapItems: [MKMapItem]
    @Binding var selectedMapItem: MKMapItem?
    
    private var sortedItems: [MKMapItem]{
        
        guard let userLocation = LocationManager.shared.manager.location else{
            return mapItems
        }
        return mapItems.sorted{lhs, rhs in
            guard let lhsLocation = lhs.placemark.location,
                  let rhsLocation = rhs.placemark.location else{
                return false
            }
            let lhsDistance = userLocation.distance(from: lhsLocation)
            let rhsDistance = userLocation.distance(from: rhsLocation)
            
            return lhsDistance<rhsDistance

        }
    }
    
    var body: some View {
        List(sortedItems, id: \.self,selection: $selectedMapItem){mapItem in
            PlaceView(mapItem: mapItem)
        }
    }
}
