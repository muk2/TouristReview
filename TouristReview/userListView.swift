import SwiftUI
import Firebase
import FirebaseStorage
import FirebaseFirestore
import MapKit


struct User: Identifiable {
    let id: String
    let name: String
    let profilePicFilename: String
    var profilePicUrl: URL?
}

struct UserListView: View {
    @State private var users: [User] = []
    @State private var searchText = ""

    // Filtered list based on search text
    var filteredUsers: [User] {
        if searchText.isEmpty {
            return users
        } else {
            return users.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }

    var body: some View {
        NavigationView {
            List(filteredUsers) { user in
                NavigationLink(destination: UserProfileView(userId: user.id)) {
                    HStack {
                        if let url = user.profilePicUrl {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable()
                                         .aspectRatio(contentMode: .fill)
                                         .frame(width: 50, height: 50)
                                         .clipShape(Circle())
                                case .failure(_), .empty:
                                    Color.gray.frame(width: 50, height: 50).clipShape(Circle())
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Color.gray.frame(width: 50, height: 50).clipShape(Circle())
                        }
                        Text(user.name)
                    }
                }
            }
            .onAppear {
                fetchUsers()
            }
            .searchable(text: $searchText)
            .navigationTitle("Find Other Users")
        }
    }
    
    func fetchUsers() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("No logged in user found")
            return
        }

        let db = Firestore.firestore()
        db.collection("users").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Error fetching documents: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            var fetchedUsers: [User] = []
            let group = DispatchGroup()
            
            for doc in documents where doc.documentID != currentUserId {
                let data = doc.data()
                guard let name = data["name"] as? String,
                      let profilePic = data["profilePic"] as? String else { continue }
                
                let user = User(id: doc.documentID, name: name, profilePicFilename: profilePic)
                fetchedUsers.append(user)
                
                let storageRef = Storage.storage().reference(withPath: "profilePics/\(profilePic)")
                group.enter()
                storageRef.downloadURL { url, error in
                    defer { group.leave() }
                    if let url = url {
                        if let index = fetchedUsers.firstIndex(where: { $0.id == doc.documentID }) {
                            fetchedUsers[index].profilePicUrl = url
                        }
                    } else {
                        print("Error downloading URL: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.users = fetchedUsers
            }
        }
    }
}













struct UserProfileView: View {
    var userId: String
    @State private var userProf: UserProf?
    @State private var profileImage: UIImage?
    @State private var ratedPlacesMapItems: [MKMapItem] = []
    @State private var isFriendRequestPending = false
    @State private var isFriend = false
    @State private var selectedMapItem: MKMapItem?
    @State private var isDetailSheetPresented = false
    @State private var ratings: [UserRating] = []
    @State private var lookAroundScene: MKLookAroundScene?
    @State private var showZoomedImage = false
    //var refreshRatings: () async -> Void




    var body: some View {
        ScrollView {
            VStack {
                if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                    
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 150, height: 150)
                }

                Text(userProf?.name ?? "Loading...")
                    .font(.title)

                if let bio = userProf?.bio, userProf?.profilePermissions == "Public" || isFriend {
                    Text(bio)
                        .font(.body)
                        .padding()
                } else {
                    Text("Bio is private")
                        .font(.body)
                        .padding()
                }

                if !isFriendRequestPending && !isFriend {
                    Button("Add Friend") {
                        sendFriendRequest()
                    }
                }
                if isFriendRequestPending{
                    Text("Friend Request Pending").border(/*@START_MENU_TOKEN@*/Color.black/*@END_MENU_TOKEN@*/)
                }
                
                if userProf?.profilePermissions == "Public" || isFriend{
                    
                    Text("Rated Places")
                        .font(.headline)
                        .padding(.top)
                    
                    ForEach(ratedPlacesMapItems, id: \.self) { mapItem in
                        Button(action: {
                            self.selectedMapItem = mapItem
                            // Trigger fetching ratings for the selected place
                            Task {
                                self.ratings = await fetchRatings(placeMarkDescription: mapItem.placemark.description)
                            }
                            self.isDetailSheetPresented = true
                        }) {
                            PlaceView(mapItem: mapItem) // Display the place
                        }
                        .buttonStyle(BorderedButtonStyle())
                    }
                }
                
                
             }
        }
         .sheet(isPresented: $isDetailSheetPresented) {
             if let mapItem = selectedMapItem {
                 VStack {
                    PlaceView(mapItem: mapItem)

                         if let selectedMapItem {
                             ActionButtons(mapItem: selectedMapItem, refreshRatings: {
                                 await self.refreshRatings()
                             }).padding()
                         }
                         if lookAroundScene != nil{
                             LookAroundPreview(initialScene: lookAroundScene)
                         }
                    
                         if ratings.isEmpty {
                             Text("Be The First To Add A Review")
                                 .font(.headline)
                                 .padding()
                         } else {
                             RatingsView(ratings: ratings)
                         }
                     
                 }             }
         }.task(id: selectedMapItem) {
             lookAroundScene = nil
             if let selectedMapItem {
                 let request = MKLookAroundSceneRequest(mapItem: selectedMapItem)
                 lookAroundScene = try? await request.scene
                // await requestCalculateDirections()
             }
         }
        .onAppear {
            fetchUserProfileAndPermissions()
            fetchUserRatedPlacesAndConvertToMapItems()
            updateFriendRequestStatus()
        }
    }
    func updateFriendRequestStatus() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        // Assume you have a way to identify the viewed user's ID (e.g., `userId`)
        let viewedUserID = userId

        let db = Firestore.firestore()
        // Check the current user's sent requests
        db.collection("users").document(currentUserID).getDocument { document, error in
            if let friendReqSent = document?.data()?["friendReqSent"] as? [String], friendReqSent.contains(viewedUserID) {
                // Current user has sent a friend request to the viewed user
                self.isFriendRequestPending = true
            } else {
                // No pending request from current user to the viewed user
                self.isFriendRequestPending = false
            }

            // Additionally, check for any other conditions you need
            // For example, checking if they are already friends or if there's a received request
        }
    }



    
    
    
    
    
    func fetchRatings(placeMarkDescription: String) async -> [UserRating] {
           let db = Firestore.firestore()
           var ratings: [UserRating] = []

           // Adjust this query according to your actual Firestore structure
           do {
               let querySnapshot = try await db.collection("Locations")
                   .whereField("placeMark", isEqualTo: placeMarkDescription)
                   .getDocuments()

               // Assuming each location has its own document and ratings are subcollections
               for document in querySnapshot.documents {
                   let ratingsSnapshot = try await db.collection("Locations")
                       .document(document.documentID)
                       .collection("Ratings")
                       .getDocuments()
                   ratings.append(contentsOf: ratingsSnapshot.documents.map { doc in
                       let data = doc.data()
                       return UserRating(
                           id: doc.documentID,
                           userName: data["userName"] as? String ?? "Anonymous",
                           rating: data["rating"] as? Int ?? 0,
                           reviewDescription: data["ratingDescription"] as? String ?? "",
                           timestamp: data["timestamp"] as? String ?? "Unknown Date"
                       )
                   })
               }
           } catch let error {
               print("Error fetching ratings: \(error.localizedDescription)")
           }
           return ratings
       }

    private func fetchUserProfileAndPermissions() {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { (document, error) in
            guard let document = document, document.exists, let data = document.data() else {
                print("Document does not exist: \(error?.localizedDescription ?? "")")
                return
            }
            self.userProf = UserProf(
                id: userId,
                name: data["name"] as? String ?? "No Name",
                bio: data["bio"] as? String,
                profilePicFilename: data["profilePic"] as? String ?? "",
                profilePermissions: data["profilePermissions"] as? String ?? "Public",
                friends: data["friends"] as? [String] ?? [],
                friendReqRec: data["friendReqRec"] as? [String] ?? [],
                friendReqSent: data["friendReqSent"] as? [String] ?? []
            )

            self.isFriendRequestPending = self.userProf?.friendReqSent.contains(Auth.auth().currentUser?.uid ?? "") ?? false
            self.isFriend = self.userProf?.friends.contains(Auth.auth().currentUser?.uid ?? "") ?? false

            if let profilePicFilename = self.userProf?.profilePicFilename {
                self.fetchProfileImage(filename: profilePicFilename)
            }
        }
    }
    private func fetchProfileImage(filename: String) {
        let storageRef = Storage.storage().reference().child("profilePics/\(filename)")
        storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
            if let error = error {
                print("Error fetching profile image: \(error.localizedDescription)")
            } else if let data = data, let image = UIImage(data: data) {
                self.profileImage = image
            }
        }
    }
    
    // Adjustments made here to fetch the rated places for the specified userId
    private func fetchUserRatedPlacesAndConvertToMapItems() {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { (document, error) in
            guard let document = document, document.exists, let ratedPlaces = document.get("rated") as? [String] else {
                print("Error fetching user rated places: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            self.findMapItemsForRatedPlaces(ratedPlaces)
        }
    }

    private func findMapItemsForRatedPlaces(_ ratedPlaces: [String]) {
        let group = DispatchGroup()
        var mapItems: [MKMapItem] = []

        for placeMarkString in ratedPlaces {
            guard let query = extractQuery(from: placeMarkString),
                  let coordinate = extractCoordinates(from: placeMarkString) else {
                print("Error parsing placeMarkString")
                continue
            }

            let searchRequest = MKLocalSearch.Request()
            searchRequest.naturalLanguageQuery = query
            // Optionally, refine the search area using the extracted coordinates
            let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
            searchRequest.region = region

            group.enter()
            let search = MKLocalSearch(request: searchRequest)
            search.start { (response, error) in
                defer { group.leave() }

                guard let response = response else {
                    print("Error searching for place: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                // Assuming the first result is the correct one; adjust as necessary
                if let firstItem = response.mapItems.first {
                    mapItems.append(firstItem)
                }
            }
        }

        group.notify(queue: .main) {
            // Now ratedPlacesMapItems should contain MKMapItems with full object structure similar to mapItems
            self.ratedPlacesMapItems = mapItems
        }
    }
        
    // extractQuery and extractCoordinates functions remain unchanged
    private func extractQuery(from placeMarkString: String) -> String? {
        // Simplified example to extract a query from placeMarkString; adjust based on actual format
        if let endIndex = placeMarkString.firstIndex(of: "@") {
            let query = String(placeMarkString[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            return query
        }
        return nil
    }

    private func extractCoordinates(from placeMarkString: String) -> CLLocationCoordinate2D? {
        if let startIndex = placeMarkString.firstIndex(of: "<"),
           let endIndex = placeMarkString.firstIndex(of: ">"),
           startIndex < endIndex {
            let coordinatesString = placeMarkString[placeMarkString.index(after: startIndex)...placeMarkString.index(before: endIndex)]
            let components = coordinatesString.split(separator: ",").compactMap { Double($0) }
            if components.count == 2 {
                return CLLocationCoordinate2D(latitude: components[0], longitude: components[1])
            }
        }
        return nil
    }
    
    // Fetch other user profile information including the profile image, similar to fetchUserProfile() but for another user
    private func sendFriendRequest() {
        let db = Firestore.firestore()
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        // Add current user ID to the friendReqRec of the viewed user
        db.collection("users").document(userId).updateData([
            "friendReqRec": FieldValue.arrayUnion([currentUserID])
        ]) { error in
            if let error = error {
                print("Error sending friend request: \(error.localizedDescription)")
            } else {
                self.isFriendRequestPending = true
            }
        }

        // Optionally, add the viewed user ID to the friendReqSent of the current user
        db.collection("users").document(currentUserID).updateData([
            "friendReqSent": FieldValue.arrayUnion([userId])
        ])
    }
}
extension UserProfileView {
    func refreshRatings() async {
        if let placemarkDescription = selectedMapItem?.placemark.description {
            self.ratings = await fetchRatings(placeMarkDescription: placemarkDescription)
            // Any other UI update needed after fetching new ratings
        }
    }
}











struct UserProf{
    var id: String
    var name: String
    var bio: String?
    var profilePicFilename: String
    var profilePermissions: String
    var friends: [String]
    var friendReqRec: [String]
    var friendReqSent: [String]
}



