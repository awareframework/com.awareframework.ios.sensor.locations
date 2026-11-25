import XCTest
import CoreLocation
import com_awareframework_ios_core
@testable import com_awareframework_ios_sensor_locations

/// Records the rows saved to it and whether they were saved on the main thread
private final class RecordingEngine: Engine {
    private let lock = NSLock()
    private(set) var savedRows = 0
    private(set) var savesOnMain = 0
    // EngineConfig has no public initializer: borrow one from an engine the package builds
    init() { super.init(Engine.Builder().build().config) }
    override func save(_ data: [any BaseDbModelSQLite], completion: ((Error?) -> Void)?) {
        lock.lock()
        savedRows += data.count
        if Thread.isMainThread { savesOnMain += 1 }
        lock.unlock()
        completion?(nil)
    }
}

/// Records the locations the sensor saves
private final class RecordingObserver: LocationsObserver {
    let onLocation: (LocationsData) -> Void
    init(_ onLocation: @escaping (LocationsData) -> Void) { self.onLocation = onLocation }
    func onLocationChanged(data: LocationsData) { onLocation(data) }
    func onExitRegion(data: GeofenceData) {}
    func onEnterRegion(data: GeofenceData) {}
    func onVisit(data: VisitData) {}
    func onHeadingChanged(data: HeadingData) {}
}

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
        XCTAssertEqual(sensor.CONFIG.sampleIntervalSeconds, 180)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy, 100)
        XCTAssertEqual(sensor.CONFIG.expirationTime, 300)
        XCTAssertEqual(sensor.CONFIG.saveAll, false)
        XCTAssertEqual(sensor.CONFIG.statusLocationVisit, true)
        XCTAssertEqual(sensor.CONFIG.statusHeading, false)
        XCTAssertEqual(sensor.CONFIG.headingFilterDegrees, 10)
        XCTAssertEqual(sensor.CONFIG.headingFilterSeconds, 1)
        XCTAssertEqual(sensor.locationManager.headingFilter, 10)
        XCTAssertEqual(sensor.CONFIG.distanceFilter, 0)
        XCTAssertEqual(sensor.CONFIG.statusSignificantLocationChanges, true)

        // negative values are rejected
        sensor = LocationsSensor(LocationsSensor.Config().apply { config in
            config.sampleIntervalSeconds    = -10
            config.minGpsAccuracy  = -100
            config.expirationTime  = -10
            config.headingFilterDegrees = -10
            config.headingFilterDegrees = 361
            config.headingFilterSeconds = -1
            config.distanceFilter = -1
            config.distanceFilter = .infinity
        })
        XCTAssertEqual(sensor.CONFIG.sampleIntervalSeconds,   180)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy, 100)
        XCTAssertEqual(sensor.CONFIG.expirationTime, 300)
        XCTAssertEqual(sensor.CONFIG.headingFilterDegrees, 10)
        XCTAssertEqual(sensor.CONFIG.headingFilterSeconds, 1)
        XCTAssertEqual(sensor.CONFIG.distanceFilter, 0)

        // apply closure
        let statusGps          = false
        let sampleIntervalSeconds:   Double = 100
        let minGpsAccuracy: Double = 100
        let expirationTime: Int64  = 100
        let saveAll            = true
        let statusLocationVisit = false
        let statusHeading = true
        let headingFilterDegrees: CLLocationDegrees = 25
        let headingFilterSeconds: TimeInterval = 2.5
        let distanceFilter: Double = 25
        let statusSignificantLocationChanges = false

        sensor = LocationsSensor(LocationsSensor.Config().apply { config in
            config.statusGps            = statusGps
            config.statusLocationVisit  = statusLocationVisit
            config.statusHeading        = statusHeading
            config.headingFilterDegrees = headingFilterDegrees
            config.headingFilterSeconds = headingFilterSeconds
            config.sampleIntervalSeconds         = sampleIntervalSeconds
            config.minGpsAccuracy       = minGpsAccuracy
            config.expirationTime       = expirationTime
            config.saveAll              = saveAll
            config.distanceFilter        = distanceFilter
            config.statusSignificantLocationChanges = statusSignificantLocationChanges
        })
        XCTAssertEqual(sensor.CONFIG.statusGps,           statusGps)
        XCTAssertEqual(sensor.CONFIG.sampleIntervalSeconds,        sampleIntervalSeconds)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy,      minGpsAccuracy)
        XCTAssertEqual(sensor.CONFIG.expirationTime,      expirationTime)
        XCTAssertEqual(sensor.CONFIG.saveAll,             saveAll)
        XCTAssertEqual(sensor.CONFIG.statusLocationVisit, statusLocationVisit)
        XCTAssertEqual(sensor.CONFIG.statusHeading, statusHeading)
        XCTAssertEqual(sensor.CONFIG.headingFilterDegrees, headingFilterDegrees)
        XCTAssertEqual(sensor.CONFIG.headingFilterSeconds, headingFilterSeconds)
        XCTAssertEqual(sensor.locationManager.headingFilter, headingFilterDegrees)
        XCTAssertEqual(sensor.CONFIG.distanceFilter,      distanceFilter)
        XCTAssertEqual(
            sensor.CONFIG.statusSignificantLocationChanges, statusSignificantLocationChanges)

        // dictionary init
        let config: [String: Any] = [
            "statusGps": statusGps,
            "sampleIntervalSeconds": sampleIntervalSeconds,
            "minGpsAccuracy": minGpsAccuracy,
            "expirationTime": expirationTime,
            "statusLocationVisit": statusLocationVisit,
            "statusHeading": statusHeading,
            "headingFilterDegrees": headingFilterDegrees,
            "headingFilterSeconds": headingFilterSeconds,
            "saveAll": saveAll,
            "distanceFilter": distanceFilter,
            "statusSignificantLocationChanges": statusSignificantLocationChanges
        ]
        sensor = LocationsSensor(LocationsSensor.Config(config))
        XCTAssertEqual(sensor.CONFIG.statusGps,           statusGps)
        XCTAssertEqual(sensor.CONFIG.sampleIntervalSeconds,        sampleIntervalSeconds)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy,      minGpsAccuracy)
        XCTAssertEqual(sensor.CONFIG.expirationTime,      expirationTime)
        XCTAssertEqual(sensor.CONFIG.saveAll,             saveAll)
        XCTAssertEqual(sensor.CONFIG.statusLocationVisit, statusLocationVisit)
        XCTAssertEqual(sensor.CONFIG.statusHeading, statusHeading)
        XCTAssertEqual(sensor.CONFIG.headingFilterDegrees, headingFilterDegrees)
        XCTAssertEqual(sensor.CONFIG.headingFilterSeconds, headingFilterSeconds)
        XCTAssertEqual(sensor.locationManager.headingFilter, headingFilterDegrees)
        XCTAssertEqual(sensor.CONFIG.distanceFilter,      distanceFilter)
        XCTAssertEqual(
            sensor.CONFIG.statusSignificantLocationChanges, statusSignificantLocationChanges)

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

    func testHeadingAngleFilterCanBeDisabled() {
        let sensor = LocationsSensor(LocationsSensor.Config().apply { config in
            config.headingFilterDegrees = 0
        })

        XCTAssertEqual(sensor.CONFIG.headingFilterDegrees, 0)
        XCTAssertEqual(sensor.locationManager.headingFilter, kCLHeadingFilterNone)
    }

    func testHeadingTimeFilterDeliversLatestValueAtTrailingEdge() {
        let delivered = expectation(description: "leading and trailing values delivered")
        delivered.expectedFulfillmentCount = 2
        var values: [Int] = []
        let filter = LatestValueTrailingThrottle<Int>(
            deliveryQueue: .main,
            monotonicNow: { 100 }
        ) { value in
            values.append(value)
            delivered.fulfill()
        }

        filter.submit(1, minimumInterval: 0.05)
        filter.submit(2, minimumInterval: 0.05)
        filter.submit(3, minimumInterval: 0.05)

        wait(for: [delivered], timeout: 1)
        XCTAssertEqual(values, [1, 3], "Only the latest pending value is delivered")
    }

    func testHeadingTimeFilterCanBeDisabled() {
        var values: [Int] = []
        let filter = LatestValueTrailingThrottle<Int>(deliveryQueue: .main) { value in
            values.append(value)
        }

        filter.submit(1, minimumInterval: 0)
        filter.submit(2, minimumInterval: 0)
        filter.submit(3, minimumInterval: 0)

        XCTAssertEqual(values, [1, 2, 3])
    }

    func testResetCancelsPendingHeading() {
        let trailingValue = expectation(description: "pending value is cancelled")
        trailingValue.isInverted = true
        var values: [Int] = []
        let filter = LatestValueTrailingThrottle<Int>(
            deliveryQueue: .main,
            monotonicNow: { 100 }
        ) { value in
            values.append(value)
            if value == 2 {
                trailingValue.fulfill()
            }
        }

        filter.submit(1, minimumInterval: 0.05)
        filter.submit(2, minimumInterval: 0.05)
        filter.reset()
        filter.submit(3, minimumInterval: 0.05)

        wait(for: [trailingValue], timeout: 0.1)
        XCTAssertEqual(
            values, [1, 3],
            "Reset cancels pending work and restarts with an immediate value")
    }

    func testNewHeadingAfterIntervalSupersedesPendingDelivery() {
        let staleValue = expectation(description: "stale pending value is not delivered")
        staleValue.isInverted = true
        var now: TimeInterval = 100
        var values: [Int] = []
        let filter = LatestValueTrailingThrottle<Int>(
            deliveryQueue: .main,
            monotonicNow: { now }
        ) { value in
            values.append(value)
            if value == 2 {
                staleValue.fulfill()
            }
        }

        filter.submit(1, minimumInterval: 0.05)
        filter.submit(2, minimumInterval: 0.05)
        now += 1
        filter.submit(3, minimumInterval: 0.05)

        wait(for: [staleValue], timeout: 0.1)
        XCTAssertEqual(values, [1, 3], "The newer immediate value cancels stale trailing work")
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

    func testLocationEventData() {
        let data = LocationEventData()
        let dict = data.toDictionary()
        XCTAssertEqual(dict["eventType"] as? String, "")
        XCTAssertEqual(dict["message"] as? String, "")
        XCTAssertEqual(dict["errorDomain"] as? String, "")
        XCTAssertEqual(dict["errorCode"] as? Int, 0)
        XCTAssertEqual(dict["authorizationStatus"] as? String, "")
        XCTAssertEqual(dict["accuracyAuthorization"] as? String, "")
        XCTAssertEqual(dict["latitude"] as? Double, 0)
        XCTAssertEqual(dict["longitude"] as? Double, 0)
        XCTAssertEqual(dict["horizontalAccuracy"] as? Double, 0)
    }

    /// Locations are saved off the main thread, in order; the notification is still posted on the main thread
    func testLocationsAreSavedOffMainAndNotifiedOnMain() {
        let sensor = LocationsSensor(LocationsSensor.Config().apply { $0.saveAll = true })
        let engine = RecordingEngine()
        sensor.dbEngine = engine

        var notifiedOnMain: [Bool] = []
        let token = NotificationCenter.default.addObserver(forName: .actionAwareLocations, object: sensor, queue: nil) { _ in
            notifiedOnMain.append(Thread.isMainThread)
        }
        let locations = (0..<5).map { CLLocation(latitude: 35.0 + Double($0) * 0.01, longitude: 139.0) }

        // From the main thread, as Core Location calls the delegate
        sensor.locationManager(sensor.locationManager, didUpdateLocations: Array(locations[0..<2]))
        // From another thread
        let done = expectation(description: "background delivery")
        DispatchQueue.global().async {
            sensor.locationManager(sensor.locationManager, didUpdateLocations: Array(locations[2..<5]))
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        // Let the main-thread notification from the background call run
        let posted = expectation(description: "posted")
        DispatchQueue.main.async { posted.fulfill() }
        wait(for: [posted], timeout: 5)

        sensor.waitForPendingSaves()
        XCTAssertEqual(engine.savedRows, 5, "every location saved")
        XCTAssertEqual(engine.savesOnMain, 0, "never saved on the main thread")
        XCTAssertEqual(notifiedOnMain, [true, true], "notifications on the main thread")
        XCTAssertEqual(sensor.LAST_DATA?.coordinate.latitude, locations[4].coordinate.latitude)
        NotificationCenter.default.removeObserver(token)
    }

    /// Locations about `meters` apart, northwards from (35, 139)
    private func track(_ meters: [Double]) -> [CLLocation] {
        meters.map { CLLocation(latitude: 35.0 + $0 / 111_195, longitude: 139.0) }
    }

    private func savedLatitudes(_ config: LocationsSensor.Config, updates: [[CLLocation]]) -> [Double] {
        let sensor = LocationsSensor(config)
        sensor.dbEngine = RecordingEngine()
        var saved: [Double] = []
        let observer = RecordingObserver { saved.append($0.latitude) }
        sensor.CONFIG.sensorObserver = observer
        for update in updates {
            sensor.locationManager(sensor.locationManager, didUpdateLocations: update)
        }
        sensor.waitForPendingSaves()
        return saved
    }

    /// saveAll = true: every location
    func testSaveAllSavesEveryLocation() {
        let points = track([0, 5, 10, 150, 160])
        let saved = savedLatitudes(LocationsSensor.Config().apply { $0.saveAll = true },
                                   updates: points.map { [$0] })
        XCTAssertEqual(saved.count, 5)
    }

    /// saveAll = false: the first location, then only moves of minGpsAccuracy from the last saved one
    func testMovesOfMinGpsAccuracyAreSaved() {
        let points = track([0, 30, 99, 120, 150, 230, 240])
        let saved = savedLatitudes(LocationsSensor.Config().apply { $0.minGpsAccuracy = 100 },
                                   updates: points.map { [$0] })
        // 0 (first), 120 (120 m from 0), 230 (110 m from 120)
        XCTAssertEqual(saved, [points[0], points[3], points[5]].map(\.coordinate.latitude))
    }

    /// The distance filter, when set, is the threshold instead of minGpsAccuracy
    func testDistanceFilterTakesPrecedence() {
        let points = track([0, 30, 99, 120, 150, 230, 240])
        let config = LocationsSensor.Config().apply {
            $0.minGpsAccuracy = 100
            $0.distanceFilter = 50
        }
        XCTAssertEqual(LocationsSensor(config).saveDistanceThreshold, 50)
        let saved = savedLatitudes(config, updates: points.map { [$0] })
        // 0, 99 (99 m from 0), 150 (51 m), 230 (80 m)
        XCTAssertEqual(saved, [points[0], points[2], points[4], points[5]].map(\.coordinate.latitude))
    }

    /// Several locations in one update are checked one by one
    func testLocationsOfOneUpdateAreCheckedInOrder() {
        let points = track([0, 60, 110, 170, 230])
        let saved = savedLatitudes(LocationsSensor.Config().apply { $0.minGpsAccuracy = 100 },
                                   updates: [points])
        // 0, 110 (110 m from 0), 230 (120 m from 110)
        XCTAssertEqual(saved, [points[0], points[2], points[4]].map(\.coordinate.latitude))
    }

    /// The distance filter can be changed while the sensor runs: Core Location and the save threshold
    func testSetDistanceFilter() {
        let sensor = LocationsSensor(LocationsSensor.Config().apply { $0.distanceFilter = 10 })
        XCTAssertEqual(sensor.locationManager.distanceFilter, 10)
        XCTAssertEqual(sensor.saveDistanceThreshold, 10)

        sensor.setDistanceFilter(250)
        XCTAssertEqual(sensor.CONFIG.distanceFilter, 250)
        XCTAssertEqual(sensor.locationManager.distanceFilter, 250)
        XCTAssertEqual(sensor.saveDistanceThreshold, 250)

        sensor.setDistanceFilter(-5)   // ignored
        XCTAssertEqual(sensor.locationManager.distanceFilter, 250)

        sensor.setDistanceFilter(0)    // off: Core Location default, minGpsAccuracy for saving
        XCTAssertEqual(sensor.locationManager.distanceFilter, kCLDistanceFilterNone)
        XCTAssertEqual(sensor.saveDistanceThreshold, sensor.CONFIG.minGpsAccuracy)
    }

    func testSyncModule() throws {
        throw XCTSkip("Sync integration test requires external server configuration.")
    }
}
