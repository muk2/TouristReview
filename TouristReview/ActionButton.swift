//
//  ActionButton.swift
//  TouristReview
//
//  Created by Mukund Chanchlani on 3/23/24.
//

import SwiftUI
import MapKit

struct ActionButtons: View {
    
    let mapItem: MKMapItem
    @State private var showingRatingView = false
    var refreshRatings: () async -> Void // Add this line


    
    var body: some View {
        HStack{
            Button(action: {
                if let phone = mapItem.phoneNumber{
                    let numericPhoneNumber=phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    makeCall(phone: numericPhoneNumber)
                }
            }, label: {
                HStack{
                    Image(systemName: "phone.fill")
                    Text("Call")
                }
            }).buttonStyle(.bordered)
            Button(action: {
                MKMapItem.openMaps(with: [mapItem])
            }, label: {
                HStack{
                    Image(systemName: "arrow.uturn.right")
                    Text("Directions").padding(.leading, 5)
                }
            }).buttonStyle(.bordered)
                .frame(width: 135)
            
            Button(action: {
                //open up rating view & send MKMapItem, in rating view add rating to firebase. save userid/rating/description/timestamp to the proper placemark. add placemark to list of rated places in user's rated map
                showingRatingView = true

                
                
            }, label: {
                HStack{
                    Image(systemName: "star.fill")
                    Text("Add Rating")
                }
            }).buttonStyle(.bordered).sheet(isPresented: $showingRatingView) {
                // Pass the current map item to the RatingView
                RatingView(mapItem: mapItem, onRatingSubmitted: {
                        await refreshRatings() // Adjust this call
                    })
            }
            
            Spacer()
            
        }//.frame(width: 500)
    }
}


