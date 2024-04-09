import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import MapKit

struct ProfileView: View {
    var mapItems: [MKMapItem]
    @Binding var selectedMapItem: MKMapItem?
    var onItemSelect: () -> Void

    @State private var userProfile: UserProfile?
    @State private var profileImage: UIImage?
    @State private var showingEditProfileView = false
    @State private var showingFriendsList = false
    @State private var showingFriendRequests = false

    var body: some View {
        VStack {
            if let userProfile = userProfile {
                Button(action: { self.showingEditProfileView = true }) {
                    if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                    } else {
                        // Placeholder image or a loading view
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 150, height: 150)
                    }
                }

                Text(userProfile.name)
                    .font(.title)

                if let bio = userProfile.bio {
                    Text(bio)
                        .font(.body)
                        .padding()
                }
                HStack {
                    Button("Friends") {
                        showingFriendsList = true
                    }
                    .padding()

                    Button("Manage Friend Requests") {
                        showingFriendRequests = true
                    }
                    .padding()
                }
            } else {
                Text("Loading profile...")
            }

            if mapItems.isEmpty {
                Text("You haven't rated any places yet.")
            } else {
                List(mapItems, id: \.self) { mapItem in
                    Button(action: {
                        self.selectedMapItem = mapItem
                        self.onItemSelect()
                    }) {
                        PlaceView(mapItem: mapItem)
                    }
                }
            }
        }
        .navigationBarItems(trailing: Button(action: { self.showingEditProfileView = true }) {
            Text("Settings")
        })
        .sheet(isPresented: $showingEditProfileView) {
            EditProfileView(userProfile: $userProfile, profileImage: $profileImage)
        }.sheet(isPresented: $showingFriendsList) {
            FriendListView()
        }
        .sheet(isPresented: $showingFriendRequests) {
           FriendRequestsManagerView()
        }
        .onAppear {
            fetchUserProfile()
        }
    }
    
    
    
    
    
    
    
    
    
    struct FriendListView: View {
        @Environment(\.presentationMode) var presentationMode
        @State private var friends: [User] = []

        var body: some View {
            NavigationView {
                List(friends) { friend in
                    NavigationLink(destination: UserProfileView(userId: friend.id)) {
                        FriendRow(user: friend)
                    }
                }
                .navigationBarTitle("Friends", displayMode: .inline)
                .navigationBarItems(trailing: Button("Done") { presentationMode.wrappedValue.dismiss() })
                .onAppear {
                    fetchFriends()
                }
            }
        }

        private func fetchFriends() {
            guard let currentUserID = Auth.auth().currentUser?.uid else { return }
            let db = Firestore.firestore()

            // Fetch the currentUser's friends list
            db.collection("users").document(currentUserID).getDocument { document, error in
                if let document = document, document.exists, let data = document.data(), let friendIds = data["friends"] as? [String] {
                    self.fetchUsersDetails(userIds: friendIds) { users in
                        DispatchQueue.main.async {
                            self.friends = users
                        }
                    }
                }
            }
        }

        private func fetchUsersDetails(userIds: [String], completion: @escaping ([User]) -> Void) {
            let db = Firestore.firestore()
            var users: [User] = []
            let group = DispatchGroup()

            userIds.forEach { userId in
                group.enter()
                // Fetch details for each user in the friends list
                db.collection("users").document(userId).getDocument { document, error in
                    if let document = document, document.exists, let data = document.data() {
                        let name = data["name"] as? String ?? "Unknown"
                        let profilePicFilename = data["profilePic"] as? String ?? ""

                        // Prepare a newUser object with available data
                        var newUser = User(id: userId, name: name, profilePicFilename: profilePicFilename, profilePicUrl: nil)

                        // If a profile picture filename exists, fetch its URL
                        if !profilePicFilename.isEmpty {
                            let storageRef = Storage.storage().reference(withPath: "profilePics/\(profilePicFilename)")
                            storageRef.downloadURL { url, error in
                                if let url = url {
                                    newUser.profilePicUrl = url
                                }
                                // Append the user whether or not the image URL was fetched
                                users.append(newUser)
                                group.leave()
                            }
                        } else {
                            // If no profile picture, append the user directly
                            users.append(newUser)
                            group.leave()
                        }
                    } else {
                        print("Error fetching user details for userId \(userId): \(error?.localizedDescription ?? "Unknown error")")
                        group.leave()
                    }
                }
            }

            // Once all user details (and possibly profile picture URLs) have been fetched
            group.notify(queue: .main) {
                completion(users)
            }
        }
    }

    struct FriendRow: View {
        var user: User

        var body: some View {
            HStack {
                if let url = user.profilePicUrl {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill).frame(width: 50, height: 50).clipShape(Circle())
                        default:
                            Circle().fill(Color.gray).frame(width: 50, height: 50)
                        }
                    }
                } else {
                    Circle().fill(Color.gray).frame(width: 50, height: 50)
                }
                Text(user.name)
                Spacer()
            }
        }
    }


    
    
    
    
    
    
    
    
    struct FriendRequestsManagerView: View {
        @Environment(\.presentationMode) var presentationMode
        @State private var tabSelection = 0
        // States to hold user details
        @State private var receivedRequests: [User] = []
        @State private var sentRequests: [User] = []
        
        var body: some View {
            NavigationView {
                VStack {
                    Picker("Requests", selection: $tabSelection) {
                        Text("Received").tag(0)
                        Text("Sent").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    if tabSelection == 0 {
                        List(receivedRequests) { user in
                            requestRow(user: user, isRecTab: true)
                        }
                    } else {
                        List(sentRequests) { user in
                            requestRow(user: user, isRecTab: false) // Sent requests might not need an action
                        }
                    }
                }
                .navigationBarTitle("Friend Requests", displayMode: .inline)
                .navigationBarItems(trailing: Button("Done") { presentationMode.wrappedValue.dismiss() })
                .onAppear {
                    fetchFriendRequests()
                }
            }
        }
        
        private func requestRow(user: User, isRecTab: Bool) -> some View {
             HStack {
                 NavigationLink(destination: UserProfileView(userId: user.id)) {
                     if let url = user.profilePicUrl {
                         AsyncImage(url: url) { phase in
                             switch phase {
                             case .success(let image):
                                 image.resizable().aspectRatio(contentMode: .fill).frame(width: 50, height: 50).clipShape(Circle())
                             default:
                                 Circle().fill(Color.gray).frame(width: 50, height: 50)
                             }
                         }
                     } else {
                         Circle().fill(Color.gray).frame(width: 50, height: 50)
                     }
                 }
                 .buttonStyle(PlainButtonStyle()) // Prevent the entire row from being clickable
                 
                 Text(user.name)
                 
                 Spacer()
                     if isRecTab{
                         Button("Accept") {
                             
                         }.onTapGesture {
                             acceptFriendRequest(from: user.id)
                             self.receivedRequests.removeAll { $0.id == user.id } // Refresh UI
                         }
                         Button("Reject") {
                             
                         }.onTapGesture {
                             rejectFriendRequest(from: user.id)
                             self.receivedRequests.removeAll { $0.id == user.id } // Refresh UI
                             
                         }
                     }
                 
                 
                 
             }
         }
        
        // Fetch friend requests from Firestore
        func fetchFriendRequests() {
            guard let currentUserID = Auth.auth().currentUser?.uid else { return }
            let db = Firestore.firestore()
            
            // Fetch received requests
            db.collection("users").document(currentUserID).getDocument { (document, error) in
                if let document = document, document.exists, let data = document.data() {
                    if let friendReqRecIds = data["friendReqRec"] as? [String] {
                        self.fetchUsersDetails(userIds: friendReqRecIds) { users in
                            self.receivedRequests = users
                        }
                    }
                    if let friendReqSentIds = data["friendReqSent"] as? [String] {
                        self.fetchUsersDetails(userIds: friendReqSentIds) { users in
                            self.sentRequests = users
                        }
                    }
                } else {
                    print("Document does not exist or failed to fetch friend requests: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
        
        func fetchUsersDetails(userIds: [String], completion: @escaping ([User]) -> Void) {
            let db = Firestore.firestore()
            var users: [User] = []
            
            let group = DispatchGroup()
            
            userIds.forEach { userId in
                group.enter()
                db.collection("users").document(userId).getDocument { (document, error) in
                    defer { group.leave() }
                    
                    if let document = document, document.exists, let data = document.data() {
                        let newUser = User(
                            id: userId,
                            name: data["name"] as? String ?? "Unknown",
                            profilePicFilename: data["profilePic"] as? String ?? "",
                            profilePicUrl: nil // This will be set below
                        )
                        users.append(newUser)
                        
                        // Fetch the profile picture URL
                        if let profilePicFilename = data["profilePic"] as? String, !profilePicFilename.isEmpty {
                            group.enter() // Enter again for the URL fetch
                            let storageRef = Storage.storage().reference(withPath: "profilePics/\(profilePicFilename)")
                            storageRef.downloadURL { url, _ in
                                defer { group.leave() } // Leave after URL fetch
                                
                                if let url = url {
                                    if let index = users.firstIndex(where: { $0.id == userId }) {
                                        users[index].profilePicUrl = url
                                    }
                                }
                            }
                        }
                    } else {
                        print("Failed to fetch user details: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
            
            group.notify(queue: .main) {
                completion(users)
            }
        }
        
        // Logic to accept a friend request
        func acceptFriendRequest(from userId: String) {
            guard let currentUserID = Auth.auth().currentUser?.uid else { return }
            let db = Firestore.firestore()
            
            // Update the currentUser's friends and remove from friendReqRec
            db.collection("users").document(currentUserID).updateData([
                "friends": FieldValue.arrayUnion([userId]),
                "friendReqRec": FieldValue.arrayRemove([userId])
            ])
            
            // Update the requester's friends and remove from friendReqSent
            db.collection("users").document(userId).updateData([
                "friends": FieldValue.arrayUnion([currentUserID]),
                "friendReqSent": FieldValue.arrayRemove([currentUserID])
            ])
        }
        
        // Logic to reject a friend request
        func rejectFriendRequest(from userId: String) {
            guard let currentUserID = Auth.auth().currentUser?.uid else { return }
            let db = Firestore.firestore()
            
            // Remove from the currentUser's friendReqRec
            db.collection("users").document(currentUserID).updateData([
                "friendReqRec": FieldValue.arrayRemove([userId])
            ])
            
            // Remove from the requester's friendReqSent
            db.collection("users").document(userId).updateData([
                "friendReqSent": FieldValue.arrayRemove([currentUserID])
            ])
        }
    }

    
    
    
    
    
    
    
    
    
    
    
    
    

    func fetchUserProfile() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { (document, error) in
            guard let document = document, document.exists, let data = document.data() else {
                print("Document does not exist: \(error?.localizedDescription ?? "")")
                return
            }
            let name = data["name"] as? String ?? "No Name"
            let bio = data["bio"] as? String
            let profilePicFilename = data["profilePic"] as? String ?? ""
            self.userProfile = UserProfile(name: name, bio: bio, profilePicFilename: profilePicFilename)

            if !profilePicFilename.isEmpty {
                // Fetch the image from Firebase Storage
                self.fetchProfileImage(filename: profilePicFilename)
            }
        }
    }

    func fetchProfileImage(filename: String) {
        let storageRef = Storage.storage().reference().child("profilePics/\(filename)")
        storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
            if let error = error {
                print("Error fetching profile image: \(error.localizedDescription)")
                return
            }
            if let data = data, let image = UIImage(data: data) {
                self.profileImage = image
            }
        }
    }
}

struct UserProfile {
    var name: String
    var bio: String?
    var profilePicFilename: String
}



// Placeholder for EditProfileView, implement UI for editing profile here
struct EditProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var userProfile: UserProfile?
    @Binding var profileImage: UIImage?
    
    @State private var editedName: String = ""
    @State private var editedBio: String = ""
    @State private var editedImage: UIImage?
    @State private var isImagePickerPresented = false
    
    init(userProfile: Binding<UserProfile?>, profileImage: Binding<UIImage?>) {
        self._userProfile = userProfile
        self._profileImage = profileImage
        self._editedName = State(initialValue: userProfile.wrappedValue?.name ?? "")
        self._editedBio = State(initialValue: userProfile.wrappedValue?.bio ?? "")
        self._editedImage = State(initialValue: profileImage.wrappedValue)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Picture")) {
                    Button(action: {
                        self.isImagePickerPresented = true
                    }) {
                        if let editedImage = editedImage {
                            Image(uiImage: editedImage)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Text("Select Image")
                        }
                    }
                }
                
                Section(header: Text("Name")) {
                    TextField("Name", text: $editedName)
                }
                
                Section(header: Text("Bio")) {
                    TextField("Bio", text: $editedBio)
                }
            }
            .navigationBarTitle("Edit Profile", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Save") {
                saveChanges()
            })
            .sheet(isPresented: $isImagePickerPresented) {
                ImagePicker(selectedImage: $editedImage, sourceType: .photoLibrary)
            }
        }
    }
    
    private func saveChanges() {
        guard let userId = Auth.auth().currentUser?.uid,
              let userProfile = userProfile else { return }

        // Define the Firestore database reference
        let db = Firestore.firestore()
        let userDocRef = db.collection("users").document(userId)

        // Handle the profile image change
        if let editedImage = editedImage, editedImage != profileImage {
            // Generate a unique filename for the new image
            let filename = "\(UUID().uuidString).jpg"
            let storageRef = Storage.storage().reference().child("profilePics/\(filename)")
            
            // Convert the image to JPEG data
            guard let imageData = editedImage.jpegData(compressionQuality: 0.75) else { return }

            // Upload the new image
            storageRef.putData(imageData, metadata: nil) { metadata, error in
                guard error == nil else {
                    print("Failed to upload profile image")
                    return
                }
                
                // If there was a previous image, delete it from Firebase Storage
                if !userProfile.profilePicFilename.isEmpty {
                    let oldRef = Storage.storage().reference().child("profilePics/\(userProfile.profilePicFilename)")
                    oldRef.delete { error in
                        if let error = error {
                            print("Error deleting old profile image: \(error.localizedDescription)")
                        }
                    }
                }

                
                // Update Firestore with the new profile information
                let updatedData: [String: Any] = [
                    "name": editedName,
                    "bio": editedBio,
                    "profilePic": filename  // Save the new filename
                ]
                
                userDocRef.updateData(updatedData) { error in
                    if let error = error {
                        print("Error updating user profile: \(error.localizedDescription)")
                    } else {
                        // Update the local user profile state
                        DispatchQueue.main.async {
                            self.userProfile?.name = self.editedName
                            self.userProfile?.bio = self.editedBio
                            self.userProfile?.profilePicFilename = filename
                            self.profileImage = editedImage
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        } else {
            // If the image wasn't changed but other details were, update Firestore
            let updatedData: [String: Any] = ["name": editedName, "bio": editedBio]
            userDocRef.updateData(updatedData) { error in
                if let error = error {
                    print("Error updating user profile: \(error.localizedDescription)")
                } else {
                    // Update the local user profile state
                    DispatchQueue.main.async {
                        self.userProfile?.name = self.editedName
                        self.userProfile?.bio = self.editedBio
                        // Image wasn't changed, no need to update it
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    
    private func updateFirestore(userId: String, data: [String: Any]) {
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData(data) { error in
            if let error = error {
                print("Error updating document: \(error.localizedDescription)")
            } else {
                // Update local profile info
                self.userProfile?.name = editedName
                self.userProfile?.bio = editedBio
                if let editedImage = editedImage {
                    self.profileImage = editedImage
                }
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage, completion: @escaping (URL?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        
        let storageRef = Storage.storage().reference().child("profilePics/\(UUID().uuidString).jpg")
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            guard error == nil else {
                print("Failed to upload profile image")
                completion(nil)
                return
            }
            
            storageRef.downloadURL { url, error in
                guard let downloadURL = url else {
                    print("Profile image URL is unavailable")
                    completion(nil)
                    return
                }
                completion(downloadURL)
            }
        }
    }
}
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator
        return imagePicker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }

            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
