//
//  SelectedPlaceDetailView.swift
//  TouristReview
//
//  Created by Mukund Chanchlani on 3/23/24.
//

import SwiftUI
import MapKit

struct SelectedPlaceDetailView: View {
    
    @Binding var mapItem: MKMapItem?
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading){
                if let mapItem{
                    PlaceView(mapItem: mapItem)
                }
            }
            Image(systemName: "xmark.circle.fill")
                .padding([.trailing],10)
                .onTapGesture {
                    mapItem=nil
                }
        }
        
    }
}

