import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseFirestore

enum DisplayMode {
    case list
    case detail
}




struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var locationManager = LocationManager.shared
    @State private var searchText = ""
    @State private var selectedFriend: String = ""
    @State private var selectedTab = 0
    @State private var isSearching = false
    @State private var mapItems: [MKMapItem] = []
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var isSheetPresented = false
    @State private var selectedDetent: PresentationDetent = .fraction(0.15)
    @State private var selectedMapItem: MKMapItem?
    @State private var displayMode: DisplayMode = .list
    @State private var lookAroundScene: MKLookAroundScene?
    @State private var route: MKRoute?
    @State private var ratings: [UserRating] = []
    @State var ratedPlacesMapItems: [MKMapItem] = []
    @State private var isDetailSheetPresented = false
    @State private var averageRating: Double = 0.0
    @State private var top=false

    
    
    
    
    
    private func convertPlacesToMapItems(_ places: [String]) {
        for place in places {
            guard let nameAndAddress = extractNameAndAddress(from: place) else {
                print("Error parsing place string")
                continue
            }
            
            // Use MKLocalSearch to find places
            let searchRequest = MKLocalSearch.Request()
            searchRequest.naturalLanguageQuery = "\(nameAndAddress.name), \(nameAndAddress.address)"
            searchRequest.region = MKCoordinateRegion(.world)
            
            let search = MKLocalSearch(request: searchRequest)
            
            // Store each task to manage their life cycle
            _ = Task {
                let response = try? await search.start()
                if let mapItem = response?.mapItems.first {
                    DispatchQueue.main.async {
                        self.mapItems.append(mapItem)
                        self.isSheetPresented = true
                        self.displayMode = .list
                    }
                }
            }
            
            //placeConversionTasks.insert(task)
        }
    }
    private func extractCoordinate(from placeString: String) -> CLLocationCoordinate2D? {
        let coordinatePattern = "<\\+?([\\-0-9\\.]+),\\+?([\\-0-9\\.]+)>"
        guard let regex = try? NSRegularExpression(pattern: coordinatePattern),
              let match = regex.firstMatch(in: placeString, range: NSRange(location: 0, length: placeString.utf16.count)),
              match.numberOfRanges == 3,
              let latRange = Range(match.range(at: 1), in: placeString),
              let lonRange = Range(match.range(at: 2), in: placeString),
              let lat = Double(placeString[latRange]),
              let lon = Double(placeString[lonRange]) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func extractNameAndAddress(from placeString: String) -> (name: String, address: String)? {
        // Assuming format is "Name, Address @ Coordinates"
        guard let atIndex = placeString.firstIndex(of: "@"),
              let commaIndex = placeString[..<atIndex].lastIndex(of: ",") else { return nil }

        let name = String(placeString[..<commaIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let address = String(placeString[placeString.index(after: commaIndex)..<atIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (name, address)
    }



    
    
    
    
    
    func fetchFriendsTopRatedPlaces() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Fetch the current user's friends list
        let userDocument = try? await db.collection("users").document(userId).getDocument()
        guard let friendsIds = userDocument?.data()?["friends"] as? [String] else { return }
        
        var allFriendsRatedPlaces: [String] = []
        
        // For each friend, fetch their rated places
        for friendId in friendsIds {
            let friendDocument = try? await db.collection("users").document(friendId).getDocument()
            if let ratedPlaces = friendDocument?.data()?["rated"] as? [String] {
                allFriendsRatedPlaces.append(contentsOf: ratedPlaces)
            }
        }
        
        // Remove duplicates
        let uniqueRatedPlaces = Array(Set(allFriendsRatedPlaces))
        //print(uniqueRatedPlaces)
        // Convert to MKMapItems and update `mapItems`
        convertPlacesToMapItems(uniqueRatedPlaces)
        
        // Update UI to show the PlaceListView with frieFnds' top-rated places
  
    }


    
    
    
    func fetchUsers(completion: @escaping ([User]) -> Void) {
        let db = Firestore.firestore()
        db.collection("users").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Error fetching documents: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            let users: [User] = documents.compactMap { doc in
                let data = doc.data()
                guard let name = data["name"] as? String,
                      let profilePic = data["profilePic"] as? String else {
                    return nil
                }
                return User(id: doc.documentID, name: name, profilePicFilename: profilePic)
            }
            completion(users)
        }
    }


    
    
    
    private func fetchUserRatedPlacesAndConvertToMapItems() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { (document, error) in
            guard let document = document, document.exists, let ratedPlaces = document.get("rated") as? [String] else {
                print("Error fetching user rated places: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            //print(ratedPlaces)
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


    
    
    
    
    
    
    
    

    
    func fetchUserLocation() {
        DispatchQueue.global().async {
            position = .userLocation(fallback: .automatic)
        }
    }
    func refreshRatings() async {
        if let placemarkDescription = selectedMapItem?.placemark.description {
            self.ratings = await fetchRatings(placeMarkDescription: placemarkDescription)
            // Perform any additional UI updates here if necessary
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

    
    
    
    
    
    
    
    
    



    private func search() async {
        do {
            mapItems = try await performSearch(searchTerm: searchText, visibleRegion: visibleRegion)
            print(mapItems)
            isSearching = false
            // Show the draggable sheet after the search is completed
            isSheetPresented = true
        } catch {
            mapItems = []
            print(error.localizedDescription)
            isSearching = false
        }
    }
    
    
    
    
    private func clearSelection() {
        selectedMapItem = nil
        route = nil
    }
    
    

    private func requestCalculateDirections() async {
        route = nil
        if let selectedMapItem {
            guard let currentUserLocation = locationManager.manager.location else {
                return
            }
            let startingMapItem = MKMapItem(placemark: MKPlacemark(coordinate: currentUserLocation.coordinate))
            Task {
                self.route = await calculateDirection(from: startingMapItem, to: selectedMapItem)
            }
        }
    }
    
    
    

    var body: some View {
        TabView(selection: $selectedTab) {
            // Map and Search Tab
            VStack {
                if isSheetPresented {
                    HStack {
                        Button(action: {
                            if selectedMapItem != nil {
                                clearSelection()
                            } else {
                                isSheetPresented = false
                                mapItems=[]
                                searchText=""
                                route=nil
                            }
                        }) {
                            Image(systemName: "arrow.left")
                                .foregroundColor(.blue)
                                .padding(.leading)
                        }
                        Spacer()
                    }
                }

                HStack {
                    TextField("Search", text: $searchText)
                        .padding()
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .onSubmit {
                            isSearching = true
                            clearSelection()
                        }
                }

                Map(position: $position, selection: $selectedMapItem) {
                    ForEach(mapItems, id: \.self) { mapItem in
                        Marker(item: mapItem)
                    }
                    if let route {
                        MapPolyline(route)
                            .stroke(.blue, lineWidth: 5)
                    }

                    UserAnnotation()
                }

                SearchOptionsView { searchTerm in
                    switch searchTerm {
                    case "Ball Up Locs":
                        searchText = "Parks"
                    case "Friend's Top Rated":
                      //  searchText = "in progress"
                        Task {
                                 await fetchFriendsTopRatedPlaces()
                             }
                    default:
                        searchText = searchTerm
                    }

                    isSearching = true
                }
            }
            .sheet(isPresented: $isSheetPresented) {
                VStack {
                        switch displayMode {
                        case .list:
                            PlaceListView(mapItems: mapItems, selectedMapItem: $selectedMapItem)
                        case .detail:
                            SelectedPlaceDetailView(mapItem: $selectedMapItem).padding()

                            if selectedDetent == .medium || selectedDetent == .large {
                                if let selectedMapItem {
                                    ActionButtons(mapItem: selectedMapItem, refreshRatings: {
                                        await self.refreshRatings()
                                    }).padding()
                                }
                                if lookAroundScene != nil{
                                    LookAroundPreview(initialScene: lookAroundScene)
                                }
                                HStack {
                                    Image(systemName: "star.fill") // Assuming you're using SF Symbols for the star logo
                                        .foregroundColor(.yellow)
                                    Text("\(averageRating.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", averageRating) : String(averageRating))")

                                }
                                
                                
                                
                                
                            }
                            if selectedDetent == .large{
                                if ratings.isEmpty {
                                    Text("Be The First To Add A Review")
                                        .font(.headline)
                                        .padding()
                                } else {
                                    RatingsView(ratings: ratings)
                                }
                            }
                        }
                    }
                .presentationDetents([.fraction(0.15), .medium, .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .onChange(of: selectedMapItem) {
                if selectedMapItem != nil {
                    displayMode = .detail
                    if let placemarkDescription = selectedMapItem?.placemark.description {
                                    Task {
                                        //print(placemarkDescription)
                                        self.ratings = await fetchRatings(placeMarkDescription: placemarkDescription)
                                        
                                        self.averageRating = ratings.reduce(0.0, { $0 + Double($1.rating) }) / Double(ratings.count)
                                    }
                                } else {
                                    self.ratings = [] // Clear ratings if there's no selected map item
                                }
                    
                } else {
                    displayMode = .list
                    route=nil
                }
            }
            .onMapCameraChange { context in
                visibleRegion = context.region
            }
            .task(id: selectedMapItem) {
                lookAroundScene = nil
                if let selectedMapItem {
                    let request = MKLookAroundSceneRequest(mapItem: selectedMapItem)
                    lookAroundScene = try? await request.scene
                    await requestCalculateDirections()
                }
            }
            .task(id: isSearching) {
                if isSearching {
                    await search()
                }
            }
            .tabItem {
                Image(systemName: "map")
                Text("Map & Search")
            }
            .tag(0)

            // Friends Search Tab
            VStack {
                UserListView() // Use UserListView here
            }
            .tabItem {
                Image(systemName: "person.3")
                Text("Friends")
            }
            .tag(1)

            // Profile Tab
            VStack {
                Text("Click On Profile Pic To Edit Profile")
                ProfileView(
                    mapItems: ratedPlacesMapItems,
                    selectedMapItem: $selectedMapItem,
                    onItemSelect: { self.isDetailSheetPresented = true }
                )

                Button("Logout") {
                       appState.signOut() // This calls the logout method in AppState
                }
            }
            .tabItem {
                Image(systemName: "person.circle")
                Text("Profile")
            }
            .tag(2)
            .sheet(isPresented: $isDetailSheetPresented) {
                
                 // Check for non-nil selectedMapItem before presenting
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
                         
                         HStack {
                             Image(systemName: "star.fill") // Assuming you're using SF Symbols for the star logo
                                 .foregroundColor(.yellow)
                             Text("\(averageRating.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", averageRating) : String(averageRating))")
                         }

                         
                             
                             
                             
                             
                         
                        
                             if ratings.isEmpty {
                                 Text("Be The First To Add A Review")
                                     .font(.headline)
                                     .padding()
                             } else {
                                 RatingsView(ratings: ratings)
                             }
                         
                     }
                 }
             }.onChange(of: isDetailSheetPresented) {
                 
                 if isDetailSheetPresented, let mapItem = selectedMapItem {
                     
                     
                     // Use the name property directly since it contains the full placeMark string
                     let placeMarkDescription = mapItem.placemark.description
                     //print(mapItem.name ?? "")
                     //print(ratedPlacesMapItems)
                     Task {
                         self.ratings = await fetchRatings(placeMarkDescription: placeMarkDescription)
                         self.averageRating = ratings.reduce(0.0, { $0 + Double($1.rating) }) / Double(ratings.count)
                     }
                 }
                 else{
                     selectedMapItem=nil
                     route=nil
                 }
             }.task(id: selectedMapItem) {
                 lookAroundScene = nil
                 if let selectedMapItem {
                     let request = MKLookAroundSceneRequest(mapItem: selectedMapItem)
                     lookAroundScene = try? await request.scene
                    // await requestCalculateDirections()
                 }
             }

            
            .presentationDetents([.fraction(0.15), .medium, .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .onAppear {
            fetchUserLocation()
            fetchUserRatedPlacesAndConvertToMapItems()
        }
    }




}


#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
