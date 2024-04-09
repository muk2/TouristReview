import SwiftUI
import MapKit
import Firebase

struct RatingView: View {
    let mapItem: MKMapItem
    @State private var rating: Int = 0 // Placeholder for star rating
    @State private var reviewDescription: String = ""
    @Environment(\.dismiss) var dismiss
    var onRatingSubmitted: (() async -> Void)? // Add this line

    

    var body: some View {
        VStack {
            Text(mapItem.name ?? "Place Name")
                .font(.title)

            StarRatingView(rating: $rating)
                .padding()

            TextEditor(text: $reviewDescription)
                .frame(height: 200)
                .border(Color.gray, width: 1)
                .padding()

            Button("Add Review") {
                submitRating()
            }
            .buttonStyle(.borderedProminent)
            .padding()

            Spacer()
        }
        .padding()
    }

    private func submitRating() {
        let db = Firestore.firestore()
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Error: User not logged in")
            return
        }
        
        // Fetch the user's name from the Firestore users collection
        db.collection("users").document(userId).getDocument { (documentSnapshot, error) in
            if let error = error {
                print("Error fetching user data: \(error)")
                return
            }
            
            guard let document = documentSnapshot else {
                print("Document does not exist")
                return
            }
            
            let userName = document.get("name") as? String ?? "Anonymous"  // Assuming "name" is the field for the user's name

            let placeMarkString = self.mapItem.placemark.description
            let locationsRef = db.collection("Locations")
            let query = locationsRef.whereField("placeMark", isEqualTo: placeMarkString)
            
            query.getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting documents: \(error)")
                } else if let snapshot = snapshot, snapshot.documents.isEmpty {
                    // The place doesn't exist, create a new document with a subcollection
                    let newLocationRef = locationsRef.document()
                    
                    newLocationRef.setData(["placeMark": placeMarkString, "description": ""]) { error in
                        if let error = error {
                            print("Error setting document: \(error)")
                        } else {
                            // Successfully created new place, now add rating including userName
                            self.addRating(to: newLocationRef, userName: userName)
                        }
                    }
                } else {
                    // The place exists, add rating to it including userName
                    if let document = snapshot?.documents.first {
                        self.addRating(to: document.reference, userName: userName)
                    }
                }
            }
        }
        Task {
            await onRatingSubmitted?()
            dismiss()
        }
    }

    private func addRating(to locationRef: DocumentReference, userName: String) {
        let ratingRef = locationRef.collection("Ratings").document()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        
        let ratingData: [String: Any] = [
            "rating": rating,
            "ratingDescription": reviewDescription,
            "userid": Auth.auth().currentUser?.uid ?? "Anonymous",
            "userName": userName,  // Include userName in the rating data
            "timestamp": dateFormatter.string(from: Date()),
            "placeMark": mapItem.placemark.description // Assuming you want to store the full description
        ]
        
        ratingRef.setData(ratingData) { error in
            if let error = error {
                print("Error adding rating: \(error)")
            } else {
                print("Rating successfully added!")
                // Directly call the function without using self
                updateUserRatedPlaces(with: mapItem.placemark.description)
                dismiss() // If dismiss is part of the environment, it can still be called directly
            }
        }
    }

    // Make sure updateUserRatedPlaces is also adjusted if needed
    private func updateUserRatedPlaces(with placeMark: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        // Use Firestore arrayUnion operation to add the placeMark
        userRef.updateData([
            "rated": FieldValue.arrayUnion([placeMark])
        ]) { error in
            if let error = error {
                print("Error updating user's rated places: \(error)")
            } else {
                print("User's rated places updated successfully.")
            }
        }
    }



}

struct StarRatingView: View {
    @Binding var rating: Int

    var body: some View {
        HStack {
            ForEach(1...5, id: \.self) { number in
                Image(systemName: "star.fill")
                    .foregroundColor(number <= rating ? .yellow : .gray)
                    .onTapGesture {
                        rating = number
                    }
            }
        }
    }
}

// Usage in SwiftUI Preview
struct RatingView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a mock MKMapItem for previews
        RatingView(mapItem: MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))))
    }
}
