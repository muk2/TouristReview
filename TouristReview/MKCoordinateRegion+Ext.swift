//
//  MKCoordinateRegion+Ext.swift
//  TouristReview
//
//  Created by Mukund Chanchlani on 3/17/24.
//

import Foundation
import MapKit

extension MKCoordinateRegion: Equatable{
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion)->Bool{
        if lhs.center.latitude==rhs.center.latitude && lhs.span.latitudeDelta==rhs.span.latitudeDelta && lhs.span.longitudeDelta==rhs.span.longitudeDelta{
            return true
        }else{
            return false
        }
    }
    
    
    
}
