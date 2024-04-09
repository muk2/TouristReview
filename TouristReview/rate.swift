//
//  rate.swift
//  TouristReview
//
//  Created by Mukund Chanchlani on 3/27/24.
//

import Foundation
import SwiftUI
import FirebaseFirestore

struct UserRating: Identifiable {
    var id: String // A unique identifier for the rating, e.g., a Firestore document ID
    var userName: String
    var rating: Int
    var reviewDescription: String
    var timestamp: String // Now expects a string
}


struct RatingsView: View {
    var ratings: [UserRating]
    
    var body: some View {
        ScrollView{
            VStack(alignment: .leading) {
                ForEach(ratings) { rating in
                    VStack(alignment: .leading) {
                        Text(rating.userName)
                            .fontWeight(.bold)
                        HStack {
                            ForEach(0..<rating.rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                            }
                            Spacer()
                            Text(rating.timestamp) // Display the timestamp string directly
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Text(rating.reviewDescription)
                            .padding(.bottom)
                    }
                    .padding()
                }
            }
        }
    }
}



