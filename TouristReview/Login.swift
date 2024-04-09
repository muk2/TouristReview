//
//  Login.swift
//  TouristReview
//
//  Created by Mukund Chanchlani on 3/27/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import MapKit




struct AnimatedLoginView: View {
    @State private var airplaneOffset = CGSize(width: -UIScreen.main.bounds.width, height: 0)
    @State private var opacity = 0.0
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var loginError = ""

    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                Image(systemName: "airplane")
                    .font(.largeTitle)
                    .rotationEffect(.degrees(360))
                    .offset(airplaneOffset)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: false)) {
                            airplaneOffset = CGSize(width: UIScreen.main.bounds.width, height: 0)
                        }
                    }
                Text("Login")
                    .font(.largeTitle)
                    .bold()
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 2).delay(1)) {
                            opacity = 1.0
                        }
                    }
                
                // Your existing login form
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .padding()
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                if !loginError.isEmpty {
                    Text(loginError).foregroundColor(.red)
                }
                
                Button("Log In") {
                    appState.signIn(email: email, password: password)
                }.padding()
                
                NavigationLink("Register", destination: RegistrationView())
                    .padding()
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
}






class AppState: ObservableObject {
    @Published var isAuthenticated = false


    private var db = Firestore.firestore()
    private var handle: AuthStateDidChangeListenerHandle?
    
    
    
   
    
    

    init() {
        setupAuthStateListener()
    }
    
    
    private func setupAuthStateListener() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isAuthenticated = user != nil
        }
    }
    
    

    func signIn(email: String, password: String) {
            Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
                if let user = authResult?.user {
                    print("User \(user.email!) logged in")
                    self?.isAuthenticated = true
                } else if let error = error {
                    print("Login error: \(error.localizedDescription)")
                }
            }
        }
        
        func signOut() {
            do {
                try Auth.auth().signOut()
                self.isAuthenticated = false
            } catch let signOutError as NSError {
                print("Error signing out: %@", signOutError)
            }
        }
    
    
    

    func registerUser(email: String, password: String, name: String, profilePermissions: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(error)
            } else if let userId = authResult?.user.uid {
                let userData: [String: Any] = [
                    "name": name,
                    "email": email,
                    "userid": userId,
                    "friendReqSent": [],
                    "friendReqRec": [],
                    "friends": [],
                    "rated": [],
                    "bio": "",
                    "profilePic": "",
                    "profilePermissions": profilePermissions // Add profile permissions to user data
                ]
                self.saveUserData(userId: userId, userData: userData, completion: completion)
            }
        }
        
        
        
        
        
        
    }


    private func saveUserData(userId: String, userData: [String: Any], completion: @escaping (Error?) -> Void) {
        db.collection("users").document(userId).setData(userData) { error in
            completion(error)
        }
    }

    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}


struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var loginError = ""
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            VStack {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .padding()
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                if !loginError.isEmpty {
                    Text(loginError).foregroundColor(.red)
                }
                Button("Log In") {
                    Auth.auth().signIn(withEmail: email, password: password) { result, error in
                        if let error = error {
                            self.loginError = error.localizedDescription
                        } else {
                            // Handle successful login if necessary
                        }
                    }
                }.padding()
                NavigationLink("Register", destination: RegistrationView())
                    .padding()
            }.navigationBarTitle("Login")
        }
    }
}


struct RegistrationView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var registrationError = ""
    @State private var profilePermissions = "Public" // Default value
    @EnvironmentObject var appState: AppState

    let profilePermissionsOptions = ["Public","Friends-Only"]

    var body: some View {
        Form {
            TextField("Name", text: $name)
            TextField("Email", text: $email)
            SecureField("Password", text: $password)
            
            Picker("Profile Permissions", selection: $profilePermissions) {
                ForEach(profilePermissionsOptions, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            if !registrationError.isEmpty {
                Text(registrationError).foregroundColor(.red)
            }
            Button("Register") {
                appState.registerUser(email: email, password: password, name: name, profilePermissions: profilePermissions) { error in
                    if let error = error {
                        self.registrationError = error.localizedDescription
                    } else {
                        // Handle successful registration if necessary
                    }
                }
            }
        }.navigationBarTitle("Register")
    }
}





#Preview {
    LoginView()
}
struct AnimatedLoginView_Previews: PreviewProvider {
    static var previews: some View {
        AnimatedLoginView().environmentObject(AppState())
    }
}
