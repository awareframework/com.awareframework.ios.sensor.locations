import XCTest
import RealmSwift
import com_awareframework_ios_sensor_locations
import com_awareframework_ios_sensor_core

class Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        Realm.Configuration.defaultConfiguration.inMemoryIdentifier = self.name
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testStorage(){
        #if targetEnvironment(simulator)
        print("Controller tests (start and stop) require a real device.")
        #else
        
        class Observer:LocationsObserver {
            func onHeadingChanged(data: HeadingData) {}
            weak var locationExpectation: XCTestExpectation?
            func onLocationChanged(data: LocationsData) {
                locationExpectation?.fulfill()
            }
            func onExitRegion(data: GeofenceData) {}
            func onEnterRegion(data: GeofenceData) {}
            func onVisit(data: VisitData) {}
        }
        let locationObserverExpect = expectation(description: "Location Observer")
        let observer = Observer()
        observer.locationExpectation = locationObserverExpect
        let locationSensor = LocationsSensor.init(LocationsSensor.Config().apply{config in
            config.debug = true
            config.dbType = .REALM
            config.frequencyGps = 10.0
            config.sensorObserver = observer
        })
        locationSensor.start()
        
        wait(for: [locationObserverExpect], timeout: 30)
        locationSensor.stop()
        
        #endif
        
    }

    func testControllers(){
        
        let sensor = LocationsSensor.init(LocationsSensor.Config().apply{ config in
            config.debug = true
        })
        
        /// test set label action ///
        let expectSetLabel = expectation(description: "set label")
        let newLabel = "hello"
        let labelObserver = NotificationCenter.default.addObserver(forName: .actionAwareLocationsSetLabel, object: nil, queue: .main) { (notification) in
            let dict = notification.userInfo;
            if let d = dict as? Dictionary<String,String>{
                XCTAssertEqual(d[LocationsSensor.EXTRA_LABEL], newLabel)
            }else{
                XCTFail()
            }
            expectSetLabel.fulfill()
        }
        sensor.set(label:newLabel)
        wait(for: [expectSetLabel], timeout: 5)
        NotificationCenter.default.removeObserver(labelObserver)
        
        
        /// test sync action ////
        let expectSync = expectation(description: "sync")
        let syncObserver = NotificationCenter.default.addObserver(forName: Notification.Name.actionAwareLocationsSync , object: nil, queue: .main) { (notification) in
            expectSync.fulfill()
            print("sync")
        }
        sensor.sync()
        wait(for: [expectSync], timeout: 5)
        NotificationCenter.default.removeObserver(syncObserver)
        
        
        #if targetEnvironment(simulator)

        print("Controller tests (start and stop) require a real device.")

        #else
        
        //// test start action ////
        let expectStart = expectation(description: "start")
        let observer = NotificationCenter.default.addObserver(forName: .actionAwareLocationsStart,
                                                              object: nil,
                                                              queue: .main) { (notification) in
                                                                expectStart.fulfill()
                                                                print("start")
        }
        sensor.start()
        wait(for: [expectStart], timeout: 5)
        NotificationCenter.default.removeObserver(observer)
        
        
        /// test stop action ////
        let expectStop = expectation(description: "stop")
        let stopObserver = NotificationCenter.default.addObserver(forName: .actionAwareLocationsStop, object: nil, queue: .main) { (notification) in
            expectStop.fulfill()
            print("stop")
        }
        sensor.stop()
        wait(for: [expectStop], timeout: 5)
        NotificationCenter.default.removeObserver(stopObserver)
        
        #endif
        
    }
    
    func testConfig(){
        
        let statusGps = false;
        let frequencyGps:   Double = 100;
        let minGpsAccuracy: Double = 100;
        let expirationTime: Int64  = 100;
        let saveAll = true;
        let statusLocationVisit = false;
        
        var config = Dictionary<String,Any>()
        config["statusGps"]    = statusGps
        config["frequencyGps"] = frequencyGps
        config["minGpsAccuracy"] = minGpsAccuracy
        config["expirationTime"] = expirationTime
        config["statusLocationVisit"] = statusLocationVisit
        config["saveAll"] = saveAll
        
        // default
        var sensor = LocationsSensor.init()
        XCTAssertEqual(sensor.CONFIG.statusGps, true)
        XCTAssertEqual(sensor.CONFIG.frequencyGps, 180)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy, 150)
        XCTAssertEqual(sensor.CONFIG.expirationTime, 300)
        XCTAssertEqual(sensor.CONFIG.saveAll, false)
        XCTAssertEqual(sensor.CONFIG.statusLocationVisit, true)

        sensor = LocationsSensor.init(LocationsSensor.Config().apply{config in
            config.frequencyGps = -10
            config.minGpsAccuracy = -100
            config.expirationTime = -10
        })
        XCTAssertEqual(sensor.CONFIG.frequencyGps, 180)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy, 150)
        XCTAssertEqual(sensor.CONFIG.expirationTime, 300)
        
        // apply
        sensor = LocationsSensor.init(LocationsSensor.Config().apply{config in
            config.statusGps = statusGps
            config.statusLocationVisit = statusLocationVisit
            config.frequencyGps = frequencyGps
            config.minGpsAccuracy = minGpsAccuracy
            config.expirationTime = expirationTime
            config.saveAll = saveAll
        })
        XCTAssertEqual(sensor.CONFIG.statusGps,      statusGps)
        XCTAssertEqual(sensor.CONFIG.frequencyGps,   frequencyGps)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy, minGpsAccuracy)
        XCTAssertEqual(sensor.CONFIG.expirationTime, expirationTime)
        XCTAssertEqual(sensor.CONFIG.saveAll,        saveAll)
        XCTAssertEqual(sensor.CONFIG.statusLocationVisit, statusLocationVisit)
        
        // init with dictionary
        sensor = LocationsSensor.init(LocationsSensor.Config(config))
        XCTAssertEqual(sensor.CONFIG.statusGps,      statusGps)
        XCTAssertEqual(sensor.CONFIG.frequencyGps,   frequencyGps)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy, minGpsAccuracy)
        XCTAssertEqual(sensor.CONFIG.expirationTime, expirationTime)
        XCTAssertEqual(sensor.CONFIG.saveAll,        saveAll)
        XCTAssertEqual(sensor.CONFIG.statusLocationVisit, statusLocationVisit)
        
        // set
        sensor = LocationsSensor.init()
        sensor.CONFIG.set(config: config)
        XCTAssertEqual(sensor.CONFIG.statusGps,      statusGps)
        XCTAssertEqual(sensor.CONFIG.frequencyGps,   frequencyGps)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy, minGpsAccuracy)
        XCTAssertEqual(sensor.CONFIG.expirationTime, expirationTime)
        XCTAssertEqual(sensor.CONFIG.saveAll,        saveAll)
        XCTAssertEqual(sensor.CONFIG.statusLocationVisit, statusLocationVisit)
        
        // region set
        sensor.CONFIG.addRegion(latitude: 65.05791716, longitude: 25.46925610, radius: 100, identifier: "office")
        sensor.CONFIG.addRegion(latitude: 65.0116922, longitude: 25.4707225, radius: 100, identifier: "Valkes")
        sensor.CONFIG.addRegion(latitude: 65.0132488, longitude: 25.4680278, radius: 100, identifier: "buss stop")
        XCTAssertEqual(sensor.CONFIG.regions.count, 3)
        
        let regions = ["regions":[
            ["latitude":65.05791716,
             "longitude":25.4707225,
             "radius":200.0,
             "id":"hogehoge1"]
        ]]
        sensor.CONFIG.set(config: regions)
        XCTAssertEqual(sensor.CONFIG.regions.count, 4)
        
        // Int test
        let regions2 = ["regions":[
            ["latitude":65,
             "longitude":25,
             "radius":200,
             "id":"hogehoge2"]
            ]]
        sensor.CONFIG.set(config: regions2)
        XCTAssertEqual(sensor.CONFIG.regions.count, 4)
        
        // String test
        let regions3 = ["regions":[
            ["latitude":"65.123",
             "longitude":"25.123",
             "radius":"200.00",
             "id":"hogehoge3"]
            ]]
        sensor.CONFIG.set(config: regions3)
        XCTAssertEqual(sensor.CONFIG.regions.count, 4)
        
        // remove region test
        sensor.CONFIG.removeRegion(identifier: "hogehoge1")
        XCTAssertEqual(sensor.CONFIG.regions.count, 3)
        
        sensor.CONFIG.removeRegion(identifier: "hogehoge5")
        XCTAssertEqual(sensor.CONFIG.regions.count, 3)
    }
    
    func testLocationData(){
        let dict = LocationsData().toDictionary()
        XCTAssertEqual(dict["latitude"] as? Double,0)
        XCTAssertEqual(dict["longitude"]as? Double,0)
        XCTAssertEqual(dict["course"]as? Double,0)
        XCTAssertEqual(dict["speed"]as? Double,0)
        XCTAssertEqual(dict["altitude"]as? Double,0)
        XCTAssertEqual(dict["horizontalAccuracy"]as? Double,0)
        XCTAssertEqual(dict["verticalAccuracy"]as? Double,0)
        XCTAssertEqual(dict["floor"] as? Int , 0)
    }
    
    func testVisitData(){
        let dict = VisitData().toDictionary()
        XCTAssertEqual(dict["horizontalAccuracy"] as? Double, 0)
        XCTAssertEqual(dict["latitude"] as? Double, 0)
        XCTAssertEqual(dict["longitude"] as? Double, 0)
        XCTAssertEqual(dict["name"] as? String, "")
        XCTAssertEqual(dict["address"] as? String, "")
        XCTAssertEqual(dict["departure"]  as? Int64, 0)
        XCTAssertEqual(dict["arrival"]  as? Int64, 0)
    }
    
    func testGeofenceData(){
        let dict = GeofenceData().toDictionary()
        XCTAssertEqual(dict["horizontalAccuracy"] as? Double, 0)
        XCTAssertEqual(dict["verticalAccuracy"] as? Double, 0)
        XCTAssertEqual(dict["latitude"]   as? Double, 0)
        XCTAssertEqual(dict["longitude"]  as? Double, 0)
        XCTAssertEqual(dict["onExit"]  as? Bool, false)
        XCTAssertEqual(dict["onEntry"] as? Bool, false)
        XCTAssertEqual(dict["identifier"] as? String, "")
    }
    
    func testSyncModule(){
        #if targetEnvironment(simulator)
        
        print("This test requires a real Locations.")
        
        #else
        // success //
        let sensor = LocationsSensor.init(LocationsSensor.Config().apply{ config in
            config.debug = true
            config.dbType = .REALM
            config.dbHost = "node.awareframework.com:1001"
            config.dbPath = "sync_db"
        })
        if let engine = sensor.dbEngine as? RealmEngine {
            engine.removeAll(LocationsData.self)
            for _ in 0..<100 {
                engine.save(LocationsData())
            }
        }
        let successExpectation = XCTestExpectation(description: "success sync")
        let observer = NotificationCenter.default.addObserver(forName: Notification.Name.actionAwareLocationsSyncCompletion,
                                                              object: sensor, queue: .main) { (notification) in
                                                                if let userInfo = notification.userInfo{
                                                                    if let status = userInfo["status"] as? Bool {
                                                                        if status == true {
                                                                            successExpectation.fulfill()
                                                                        }
                                                                    }
                                                                }
        }
        sensor.sync(force: true)
        wait(for: [successExpectation], timeout: 20)
        NotificationCenter.default.removeObserver(observer)
        
        ////////////////////////////////////
        
        // failure //
        let sensor2 = LocationsSensor.init(LocationsSensor.Config().apply{ config in
            config.debug = true
            config.dbType = .REALM
            config.dbHost = "node.awareframework.com.com" // wrong url
            config.dbPath = "sync_db"
        })
        let failureExpectation = XCTestExpectation(description: "failure sync")
        let failureObserver = NotificationCenter.default.addObserver(forName: Notification.Name.actionAwareLocationsSyncCompletion,
                                                                     object: sensor2, queue: .main) { (notification) in
                                                                        if let userInfo = notification.userInfo{
                                                                            if let status = userInfo["status"] as? Bool {
                                                                                if status == false {
                                                                                    failureExpectation.fulfill()
                                                                                }
                                                                            }
                                                                        }
        }
        if let engine = sensor2.dbEngine as? RealmEngine {
            engine.removeAll(LocationsData.self)
            for _ in 0..<100 {
                engine.save(LocationsData())
            }
        }
        sensor2.sync(force: true)
        wait(for: [failureExpectation], timeout: 20)
        NotificationCenter.default.removeObserver(failureObserver)
        
        #endif
    }
    
}
