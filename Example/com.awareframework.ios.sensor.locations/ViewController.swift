//
//  ViewController.swift
//  com.awareframework.ios.sensor.locations
//
//  Created by tetujin on 11/19/2018.
//  Copyright (c) 2018 tetujin. All rights reserved.
//

import UIKit
import com_awareframework_ios_sensor_locations

class ViewController: UIViewController, LocationsObserver {

    var locationSensor:LocationsSensor? = nil
    
    @IBOutlet weak var location: UILabel!
    
    @IBOutlet weak var exit: UILabel!
    
    @IBOutlet weak var enter: UILabel!
    
    @IBOutlet weak var visit: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        locationSensor = LocationsSensor(LocationsSensor.Config().apply{ config in
            config.debug = true
            config.saveAll = true
            config.statusGps = true
            config.frequencyGps = 10
            config.expirationTime = 30
            config.dbType = .REALM
            config.sensorObserver = self
            config.addRegion(latitude: 65.05791716, longitude: 25.46925610, radius: 100, identifier: "office")
            config.addRegion(latitude: 65.0116922, longitude: 25.4707225, radius: 100, identifier: "Valkes")
            config.addRegion(latitude: 65.0132488, longitude: 25.4680278, radius: 100, identifier: "buss stop")
        })
        locationSensor?.start()
    }
    
    func onLocationChanged(data: LocationsData) {
        self.location.text = "\(data.latitude), \(data.longitude)"
    }
    
    func onExitRegion(data: GeofenceData) {
        self.exit.text = "exit: \(data.identifier)"
    }
    
    func onEnterRegion(data: GeofenceData) {
        self.enter.text = "enter: \(data.identifier)"
    }
    
    func onVisit(data: VisitData) {
        self.visit.text = data.address
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

