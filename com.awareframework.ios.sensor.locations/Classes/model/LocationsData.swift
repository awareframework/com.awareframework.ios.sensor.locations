//
//  LocationsData.swift
//  com.aware.ios.sensor.core
//
//  Created by Yuuki Nishiyama on 2018/10/22.
//

import UIKit
import com_awareframework_ios_sensor_core

public class LocationsData: AwareObject {
    public static var TABLE_NAME = "locationsData"

    // CLLocationCoordinate2D
    @objc dynamic public var latitude:  Double = 0
    @objc dynamic public var longitude: Double = 0
    //open var course: CLLocationDirection { get }
    @objc dynamic public var course:    Double = 0
    //open var speed: CLLocationSpeed { get }
    @objc dynamic public var speed:     Double = 0
    // open var altitude: CLLocationDistance { get }
    @objc dynamic public var altitude:  Double = 0
    //open var horizontalAccuracy: CLLocationAccuracy { get }
    @objc dynamic public var horizontalAccuracy: Double = 0
    //open var verticalAccuracy: CLLocationAccuracy { get }
    @objc dynamic public var verticalAccuracy: Double = 0
    //@NSCopying open var floor: CLFloor? { get }
    @objc dynamic public var floor: Int = 0
    
    override public func toDictionary() -> Dictionary<String, Any> {
        var dict = super.toDictionary()
        dict["latitude"]  = latitude
        dict["longitude"] = longitude
        dict["course"]   = course
        dict["speed"]     = speed
        dict["altitude"]  = altitude
        dict["horizontalAccuracy"] = horizontalAccuracy
        dict["verticalAccuracy"]  = verticalAccuracy
        dict["floor"] = floor
        return dict
    }
}







