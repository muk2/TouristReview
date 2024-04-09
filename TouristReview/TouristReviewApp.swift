//
//  TouristReviewApp.swift
//  TouristReview
//
//  Created by Mukund Chanchlani on 3/16/24.
//
import SwiftUI
import Firebase

@main
struct TouristReviewApp: App {
    @StateObject private var appState = AppState()
    
    init(){
        FirebaseApp.configure()

    }

    var body: some Scene {
        WindowGroup {
            if appState.isAuthenticated {
                ContentView().environmentObject(appState)
            } else {
                AnimatedLoginView().environmentObject(appState)
            }
        }
    }
}

