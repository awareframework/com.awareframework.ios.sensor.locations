import XCTest
@testable import com_awareframework_ios_sensor_locations

class Tests: XCTestCase {

    func testControllers() {
        let sensor = LocationsSensor()

        // set label
        let expectSetLabel = expectation(description: "set label")
        let newLabel = "hello"
        let labelObserver = NotificationCenter.default.addObserver(
            forName: .actionAwareLocationsSetLabel, object: nil, queue: .main
        ) { notification in
            if let d = notification.userInfo as? [String: String] {
                XCTAssertEqual(d[LocationsSensor.EXTRA_LABEL], newLabel)
            } else {
                XCTFail()
            }
            expectSetLabel.fulfill()
        }
        sensor.set(label: newLabel)
        wait(for: [expectSetLabel], timeout: 5)
        NotificationCenter.default.removeObserver(labelObserver)

        // sync
        let expectSync = expectation(description: "sync")
        let syncObserver = NotificationCenter.default.addObserver(
            forName: .actionAwareLocationsSync, object: nil, queue: .main
        ) { _ in
            expectSync.fulfill()
        }
        sensor.sync()
        wait(for: [expectSync], timeout: 5)
        NotificationCenter.default.removeObserver(syncObserver)
    }

    func testConfig() {
        // default values
        var sensor = LocationsSensor()
        XCTAssertEqual(sensor.CONFIG.statusGps, true)
        XCTAssertEqual(sensor.CONFIG.frequencyGps, 180)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy, 150)
        XCTAssertEqual(sensor.CONFIG.expirationTime, 300)
        XCTAssertEqual(sensor.CONFIG.saveAll, false)
        XCTAssertEqual(sensor.CONFIG.statusLocationVisit, true)

        // negative values are rejected
        sensor = LocationsSensor(LocationsSensor.Config().apply { config in
            config.frequencyGps    = -10
            config.minGpsAccuracy  = -100
            config.expirationTime  = -10
        })
        XCTAssertEqual(sensor.CONFIG.frequencyGps,   180)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy, 150)
        XCTAssertEqual(sensor.CONFIG.expirationTime, 300)

        // apply closure
        let statusGps          = false
        let frequencyGps:   Double = 100
        let minGpsAccuracy: Double = 100
        let expirationTime: Int64  = 100
        let saveAll            = true
        let statusLocationVisit = false

        sensor = LocationsSensor(LocationsSensor.Config().apply { config in
            config.statusGps            = statusGps
            config.statusLocationVisit  = statusLocationVisit
            config.frequencyGps         = frequencyGps
            config.minGpsAccuracy       = minGpsAccuracy
            config.expirationTime       = expirationTime
            config.saveAll              = saveAll
        })
        XCTAssertEqual(sensor.CONFIG.statusGps,           statusGps)
        XCTAssertEqual(sensor.CONFIG.frequencyGps,        frequencyGps)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy,      minGpsAccuracy)
        XCTAssertEqual(sensor.CONFIG.expirationTime,      expirationTime)
        XCTAssertEqual(sensor.CONFIG.saveAll,             saveAll)
        XCTAssertEqual(sensor.CONFIG.statusLocationVisit, statusLocationVisit)

        // dictionary init
        var config: [String: Any] = [
            "statusGps": statusGps,
            "frequencyGps": frequencyGps,
            "minGpsAccuracy": minGpsAccuracy,
            "expirationTime": expirationTime,
            "statusLocationVisit": statusLocationVisit,
            "saveAll": saveAll
        ]
        sensor = LocationsSensor(LocationsSensor.Config(config))
        XCTAssertEqual(sensor.CONFIG.statusGps,           statusGps)
        XCTAssertEqual(sensor.CONFIG.frequencyGps,        frequencyGps)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy,      minGpsAccuracy)
        XCTAssertEqual(sensor.CONFIG.expirationTime,      expirationTime)
        XCTAssertEqual(sensor.CONFIG.saveAll,             saveAll)
        XCTAssertEqual(sensor.CONFIG.statusLocationVisit, statusLocationVisit)

        // regions
        sensor = LocationsSensor()
        sensor.CONFIG.addRegion(latitude: 65.05791716, longitude: 25.46925610, radius: 100, identifier: "office")
        sensor.CONFIG.addRegion(latitude: 65.0116922,  longitude: 25.4707225,  radius: 100, identifier: "Valkes")
        sensor.CONFIG.addRegion(latitude: 65.0132488,  longitude: 25.4680278,  radius: 100, identifier: "bus_stop")
        XCTAssertEqual(sensor.CONFIG.regions.count, 3)

        let regionsConfig: [String: Any] = ["regions": [
            ["latitude": 65.05791716, "longitude": 25.4707225, "radius": 200.0, "id": "extra1"]
        ]]
        sensor.CONFIG.set(config: regionsConfig)
        XCTAssertEqual(sensor.CONFIG.regions.count, 4)

        sensor.CONFIG.removeRegion(identifier: "extra1")
        XCTAssertEqual(sensor.CONFIG.regions.count, 3)

        sensor.CONFIG.removeRegion(identifier: "nonexistent")
        XCTAssertEqual(sensor.CONFIG.regions.count, 3)
    }

    func testLocationsData() {
        let data = LocationsData()
        let dict = data.toDictionary()
        XCTAssertEqual(dict["latitude"]           as? Double, 0)
        XCTAssertEqual(dict["longitude"]          as? Double, 0)
        XCTAssertEqual(dict["course"]             as? Double, 0)
        XCTAssertEqual(dict["speed"]              as? Double, 0)
        XCTAssertEqual(dict["altitude"]           as? Double, 0)
        XCTAssertEqual(dict["horizontalAccuracy"] as? Double, 0)
        XCTAssertEqual(dict["verticalAccuracy"]   as? Double, 0)
        XCTAssertEqual(dict["floor"]              as? Int,    0)
    }

    func testVisitData() {
        let data = VisitData()
        let dict = data.toDictionary()
        XCTAssertEqual(dict["horizontalAccuracy"] as? Double, 0)
        XCTAssertEqual(dict["latitude"]           as? Double, 0)
        XCTAssertEqual(dict["longitude"]          as? Double, 0)
        XCTAssertEqual(dict["name"]               as? String, "")
        XCTAssertEqual(dict["address"]            as? String, "")
        XCTAssertEqual(dict["departure"]          as? Int64,  0)
        XCTAssertEqual(dict["arrival"]            as? Int64,  0)
    }

    func testGeofenceData() {
        let data = GeofenceData()
        let dict = data.toDictionary()
        XCTAssertEqual(dict["horizontalAccuracy"] as? Double, 0)
        XCTAssertEqual(dict["verticalAccuracy"]   as? Double, 0)
        XCTAssertEqual(dict["latitude"]           as? Double, 0)
        XCTAssertEqual(dict["longitude"]          as? Double, 0)
        XCTAssertEqual(dict["onExit"]             as? Bool,   false)
        XCTAssertEqual(dict["onEntry"]            as? Bool,   false)
        XCTAssertEqual(dict["identifier"]         as? String, "")
    }

    func testHeadingData() {
        let data = HeadingData()
        let dict = data.toDictionary()
        XCTAssertEqual(dict["magneticHeading"]  as? Double, 0)
        XCTAssertEqual(dict["trueHeading"]      as? Double, 0)
        XCTAssertEqual(dict["headingAccuracy"]  as? Double, 0)
        XCTAssertEqual(dict["x"]               as? Double, 0)
        XCTAssertEqual(dict["y"]               as? Double, 0)
        XCTAssertEqual(dict["z"]               as? Double, 0)
    }

    func testSyncModule() throws {
        throw XCTSkip("Sync integration test requires external server configuration.")
    }
}
