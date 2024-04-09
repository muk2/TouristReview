//
//  MeasurementFormatter.swift
//  TouristReview
//
//  Created by Mukund Chanchlani on 3/23/24.
//

import Foundation

extension MeasurementFormatter{
    static var distance: MeasurementFormatter{
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.unitOptions = .naturalScale
        formatter.locale = Locale.current
        return formatter
    }
}


