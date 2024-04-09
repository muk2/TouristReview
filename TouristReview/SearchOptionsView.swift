//
//  SearchOptionsView.swift
//  TouristReview
//
//  Created by Mukund Chanchlani on 3/22/24.
//

import SwiftUI

struct SearchOptionsView: View {
    
    let searchOptions = ["Restaurants": "fork.knife", "Hotels": "bed.double.fill", "Gas": "fuelpump.fill", "Ball Up Locs": "tree.fill", "Friend's Top Rated": "person.3.fill"]
    
    let onSelected: (String)->Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false){
            HStack{
                ForEach(searchOptions.sorted(by: >), id: \.0){
                    key, value in Button(action: {
                        onSelected(key)
                    },
                        label: {
                        HStack{
                            Image(systemName: value)
                            Text(key)
                        }
                    })
                    .buttonStyle(.borderedProminent).tint(.black)
                    
                }
            }
        }
    }
}

#Preview {
    SearchOptionsView(onSelected: {_ in})
}
