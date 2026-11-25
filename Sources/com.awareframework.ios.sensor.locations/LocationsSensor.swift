//
//  LocationsSensor.swift
//  com.aware.ios.sensor.core
//
//  Created by Yuuki Nishiyama on 2018/10/22.
//

import CoreLocation
import UIKit
import com_awareframework_ios_core

extension Notification.Name {
    public static let actionAwareLocations = Notification.Name(
        LocationsSensor.ACTION_AWARE_LOCATIONS)
    public static let actionAwareLocationsStart = Notification.Name(
        LocationsSensor.ACTION_AWARE_LOCATIONS_START)
    public static let actionAwareLocationsStop = Notification.Name(
        LocationsSensor.ACTION_AWARE_LOCATIONS_STOP)
    public static let actionAwareLocationsSync = Notification.Name(
        LocationsSensor.ACTION_AWARE_LOCATIONS_SYNC)
    public static let actionAwareLocationsSetLabel = Notification.Name(
        LocationsSensor.ACTION_AWARE_LOCATIONS_SET_LABEL)
    public static let actionAwareLocationsSyncCompletion = Notification.Name(
        LocationsSensor.ACTION_AWARE_LOCATIONS_SYNC_COMPLETION)

    public static let actionAwareLocationsEnterRegion = Notification.Name(
        LocationsSensor.ACTION_AWARE_LOCATIONS_ENTER_REGION)
    public static let actionAwareLocationsExitRegion = Notification.Name(
        LocationsSensor.ACTION_AWARE_LOCATIONS_EXIT_REGION)

    public static let actionAwareLocationsVisit = Notification.Name(
        LocationsSensor.ACTION_AWARE_LOCATIONS_VISIT)
    public static let actionAwareLocationsHeadingChanged = Notification.Name(
        LocationsSensor.ACTION_AWARE_LOCATIONS_HEADING_CHANGED)
    public static let actionAwareLocationsEvent = Notification.Name(
        LocationsSensor.ACTION_AWARE_LOCATIONS_EVENT)
}

public protocol LocationsObserver {
    func onLocationChanged(data: LocationsData)
    func onExitRegion(data: GeofenceData)
    func onEnterRegion(data: GeofenceData)
    func onVisit(data: VisitData)
    func onHeadingChanged(data: HeadingData)
}

/// Delivers the first value immediately, then coalesces values received inside the minimum
/// interval and delivers only the latest one at the trailing edge.
final class LatestValueTrailingThrottle<Value: Sendable>: @unchecked Sendable {
    private let deliveryQueue: DispatchQueue
    private let queueKey = DispatchSpecificKey<UInt8>()
    private let queueMarker: UInt8 = 1
    private let monotonicNow: () -> TimeInterval
    private let delivery: (Value) -> Void

    private var lastDeliveryTime: TimeInterval?
    private var pendingValue: Value?
    private var pendingWorkItem: DispatchWorkItem?
    private var generation: UInt64 = 0

    init(
        deliveryQueue: DispatchQueue,
        monotonicNow: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        delivery: @escaping (Value) -> Void
    ) {
        self.deliveryQueue = deliveryQueue
        self.monotonicNow = monotonicNow
        self.delivery = delivery
        deliveryQueue.setSpecific(key: queueKey, value: queueMarker)
    }

    func submit(_ value: Value, minimumInterval: TimeInterval) {
        performSynchronously { [self] in
            submitOnDeliveryQueue(value, minimumInterval: minimumInterval)
        }
    }

    func reset() {
        performSynchronously { [self] in
            generation &+= 1
            pendingWorkItem?.cancel()
            pendingWorkItem = nil
            pendingValue = nil
            lastDeliveryTime = nil
        }
    }

    private func submitOnDeliveryQueue(_ value: Value, minimumInterval: TimeInterval) {
        let interval = max(0, minimumInterval)
        let now = monotonicNow()
        let elapsed = lastDeliveryTime.map { now - $0 }

        if interval > 0, let elapsed, elapsed >= 0, elapsed < interval {
            pendingValue = value
            if pendingWorkItem == nil {
                generation &+= 1
                let scheduledGeneration = generation
                let workItem = DispatchWorkItem { [weak self] in
                    self?.deliverPendingValue(generation: scheduledGeneration)
                }
                pendingWorkItem = workItem
                deliveryQueue.asyncAfter(
                    deadline: .now() + (interval - elapsed),
                    execute: workItem)
            }
        } else {
            generation &+= 1
            pendingWorkItem?.cancel()
            pendingWorkItem = nil
            pendingValue = nil
            lastDeliveryTime = now
            delivery(value)
        }
    }

    private func deliverPendingValue(generation scheduledGeneration: UInt64) {
        guard generation == scheduledGeneration, let pendingValue else { return }
        self.pendingValue = nil
        pendingWorkItem = nil
        lastDeliveryTime = monotonicNow()
        delivery(pendingValue)
    }

    private func performSynchronously(_ work: @escaping @Sendable () -> Void) {
        if DispatchQueue.getSpecific(key: queueKey) == queueMarker {
            work()
        } else {
            deliveryQueue.sync(execute: work)
        }
    }
}

private struct SendableHeading: @unchecked Sendable {
    let value: CLHeading
}

private final class WeakReference<Object: AnyObject>: @unchecked Sendable {
    weak var value: Object?

    init(_ value: Object) {
        self.value = value
    }
}

public class LocationsSensor: AwareSensor {

    public let locationManager = CLLocationManager()

    var visitEngine: Engine? = nil
    var geofenceEngine: Engine? = nil
    var headingEngine: Engine? = nil
    var eventEngine: Engine? = nil

    public var CONFIG: LocationsSensor.Config

    public static let TAG = "AWARE::Locations"

    var timer: Timer?
    private var hasRequestedAlwaysAuthorization = false

    public var LAST_DATA: CLLocation?

    public var LAST_HEADING: CLHeading?

    private var lastSavedLocation: CLLocation?
    private lazy var headingTimeFilter = LatestValueTrailingThrottle<SendableHeading>(
        deliveryQueue: .main
    ) { [weak self] heading in
        self?.processHeading(heading.value)
    }

    /// Rows are written to the databases here, in the order they were received, not on the main
    /// thread. Core Location calls the delegate on the thread that created `locationManager` (the
    /// main thread), and heading updates can arrive many times a second.
    private let saveQueue = DispatchQueue(
        label: "com.awareframework.ios.sensor.locations.save", qos: .utility)

    /// Saves `rows` to `engine` on `saveQueue`.
    private func save(_ rows: [any BaseDbModelSQLite], to engine: Engine?) {
        guard let engine, !rows.isEmpty else { return }
        saveQueue.async { engine.save(rows) }
    }

    /// Waits until every row handed to `save(_:to:)` so far is written. For tests.
    func waitForPendingSaves() {
        saveQueue.sync {}
    }

    /// Posts a notification on the main thread (right away when already on it).
    private func postOnMain(name: Notification.Name, object: Any?, userInfo: [AnyHashable: Any]? = nil) {
        if Thread.isMainThread {
            notificationCenter.post(name: name, object: object, userInfo: userInfo)
        } else {
            DispatchQueue.main.async {
                self.notificationCenter.post(name: name, object: object, userInfo: userInfo)
            }
        }
    }

    /**
     * Fired event: New location available
     */
    public static let ACTION_AWARE_LOCATIONS = "com.awareframework.ios.sensor.locations"

    public static let ACTION_AWARE_LOCATIONS_HEADING_CHANGED =
        "ACTION_AWARE_LOCATIONS_HEADING_CHANGED"

    public static let ACTION_AWARE_LOCATIONS_EVENT = "ACTION_AWARE_LOCATIONS_EVENT"

    /**
     * Fired event: GPS location is active
     */
    public static let ACTION_AWARE_GPS_LOCATIONS_ENABLED = "ACTION_AWARE_GPS_LOCATIONS_ENABLED"

    /**
     * Fired event: Network location is active
     */
    public static let ACTION_AWARE_NETWORK_LOCATIONS_ENABLED =
        "ACTION_AWARE_NETWORK_LOCATIONS_ENABLED"

    /**
     * Fired event: GPS location disabled
     */
    public static let ACTION_AWARE_GPS_LOCATIONS_DISABLED = "ACTION_AWARE_GPS_LOCATIONS_DISABLED"

    public static let ACTION_AWARE_LOCATIONS_ENTER_REGION = "ACTION_AWARE_LOCATION_ENTER_REGION"

    public static let ACTION_AWARE_LOCATIONS_EXIT_REGION = "ACTION_AWARE_LOCATION_EXIT_REGION"

    public static let ACTION_AWARE_LOCATIONS_VISIT = "ACTION_AWARE_LOCATION_VISIT"

    /**
     * Fired event: Network location disabled
     */
    public static let ACTION_AWARE_NETWORK_LOCATIONS_DISABLED =
        "ACTION_AWARE_NETWORK_LOCATIONS_DISABLED"

    public static let ACTION_AWARE_LOCATIONS_START =
        "com.awareframework.ios.sensor.locations.SENSOR_START"
    public static let ACTION_AWARE_LOCATIONS_STOP =
        "com.awareframework.ios.sensor.locations.SENSOR_STOP"

    public static let ACTION_AWARE_LOCATIONS_SET_LABEL =
        "com.ios.android.sensor.locations.SET_LABEL"
    public static var EXTRA_LABEL = "label"

    public static let ACTION_AWARE_LOCATIONS_SYNC =
        "com.awareframework.ios.sensor.locations.SENSOR_SYNC"

    public static let ACTION_AWARE_LOCATIONS_SYNC_COMPLETION =
        "com.awareframework.ios.sensor.locations.SENSOR_SYNC_COMPLETION"
    public static let EXTRA_STATUS = "status"
    public static let EXTRA_ERROR = "error"
    public static let EXTRA_OBJECT_TYPE = "objectType"
    public static let EXTRA_TABLE_NAME = "tableName"

    public class Config: SensorConfig {

        public var sensorObserver: LocationsObserver?
        public var geoFences: String? = nil  // TODO: convert the value to CLRegion
        public var statusGps = true
        public var statusLocationVisit = true
        public var statusHeading = false
        public var headingFilterDegrees: CLLocationDegrees = 10 {
            didSet {
                if !headingFilterDegrees.isFinite || !(0...360).contains(headingFilterDegrees) {
                    print(
                        "[LocationsSensor][Illegal Parameter] The 'headingFilterDegrees' value has to be between 0 and 360. ",
                        "This parameter (\(headingFilterDegrees)) is ignored.")
                    headingFilterDegrees = oldValue
                }
            }
        }
        public var headingFilterSeconds: TimeInterval = 1 {
            didSet {
                if !headingFilterSeconds.isFinite || headingFilterSeconds < 0 {
                    print(
                        "[LocationsSensor][Illegal Parameter] The 'headingFilterSeconds' value has to be greater than or equal to 0. ",
                        "This parameter (\(headingFilterSeconds)) is ignored.")
                    headingFilterSeconds = oldValue
                }
            }
        }
        public var sampleIntervalSeconds: Double = 180 {
            didSet {
                if self.sampleIntervalSeconds <= 0 {
                    print(
                        "[LocationsSensor][Illegal Parameter] The 'sampleIntervalSeconds' value has to be more than 0. ",
                        "This parameter (\(self.sampleIntervalSeconds)) is ignored.")
                    self.sampleIntervalSeconds = oldValue
                }
            }
        }
        /// Core Location reports a new location only after the device moved this far (meters).
        /// 0: every update (`kCLDistanceFilterNone`, the default of Core Location). With
        /// `saveAll = false`, a location is saved after a move of this distance when it is set
        /// (instead of `minGpsAccuracy`).
        public var distanceFilter: CLLocationDistance = 0 {
            didSet {
                if !distanceFilter.isFinite || distanceFilter < 0 {
                    print(
                        "[LocationsSensor][Illegal Parameter] The 'distanceFilter' value has to be greater than or equal to 0. ",
                        "This parameter (\(distanceFilter)) is ignored.")
                    distanceFilter = oldValue
                }
            }
        }
        public var minGpsAccuracy: Double = 100 {
            didSet {
                if self.minGpsAccuracy < 0 {
                    print(
                        "[LocationsSensor][Illegal Parameter] The 'minGpsAccuracy' value has to be greater than or equal to 0. ",
                        "This parameter (\(self.minGpsAccuracy)) is ignored.")
                    self.minGpsAccuracy = oldValue
                }
            }
        }

        public var expirationTime: Int64 = 300 {
            didSet {
                if self.expirationTime < 0 {
                    print(
                        "[LocationsSensor][Illegal Parameter] The 'expirationTime' value has to be greater than or equal to 0. ",
                        "This parameter (\(self.expirationTime)) is ignored.")
                    self.expirationTime = oldValue
                }
            }
        }

        /// true: every location Core Location reports is saved. false: the first location, then a
        /// location only after a move of `distanceFilter` (when set) or `minGpsAccuracy` meters from
        /// the last saved one.
        public var saveAll = false

        public var regions: [CLRegion] = [CLRegion]()

        public var accuracy: CLLocationAccuracy? = nil
        public var statusSignificantLocationChanges = true

        // iOS does not provide the network based location service
        // var statusNetwork = true;
        // var statusPassive = true;
        // var frequencyNetwork: Int = 300;
        // var minNetworkAccuracy: Int = 1500;

        public override init() {
            super.init()
            dbPath = "aware_locations"
            dbTableName = LocationsData.databaseTableName
        }

        public override func set(config: [String: Any]) {
            super.set(config: config)
            if let status = config["statusGps"] as? Bool {
                statusGps = status
            }

            if let sampleIntervalSeconds = config["sampleIntervalSeconds"] as? Double {
                self.sampleIntervalSeconds = sampleIntervalSeconds
            }

            if let minGps = config["minGpsAccuracy"] as? Double {
                minGpsAccuracy = minGps
            }

            if let expTime = config["expirationTime"] as? Int64 {
                expirationTime = expTime
            }

            if let sAll = config["saveAll"] as? Bool {
                saveAll = sAll
            }

            if let locationVisit = config["statusLocationVisit"] as? Bool {
                statusLocationVisit = locationVisit
            }

            if let heading = config["statusHeading"] as? Bool {
                statusHeading = heading
            }

            if let headingFilterDegrees = config["headingFilterDegrees"] as? Double {
                self.headingFilterDegrees = headingFilterDegrees
            }

            if let headingFilterSeconds = config["headingFilterSeconds"] as? Double {
                self.headingFilterSeconds = headingFilterSeconds
            }

            if let significantLocationChanges = config["statusSignificantLocationChanges"] as? Bool
            {
                statusSignificantLocationChanges = significantLocationChanges
            }

            if let distanceFilter = config["distanceFilter"] as? Double {
                self.distanceFilter = max(0, distanceFilter)
            }

            /// CLRegion
            if let regionsArray = config["regions"] as? [[String: Any]] {
                for regionDict in regionsArray {

                    guard let latitude = regionDict["latitude"] as? Double else {
                        print(
                            "[LocationsSensor][Illegal Parameter] There is no 'latitude' value in the Dictionary<String,Any>"
                        )
                        break
                    }

                    guard let longitude = regionDict["longitude"] as? Double else {
                        print(
                            "[LocationsSensor][Illegal Parameter] There is no 'longitude' value in the Dictionary<String,Any>"
                        )
                        break
                    }

                    guard let radius = regionDict["radius"] as? Double else {
                        print(
                            "[LocationsSensor][Illegal Parameter] There is no 'radius' value in the Dictionary<String,Any>"
                        )
                        break
                    }

                    guard let id = regionDict["id"] as? String else {
                        print(
                            "[LocationsSensor][Illegal Parameter] There is no 'id' value in the Dictionary<String,Any>"
                        )
                        break
                    }
                    self.addRegion(
                        latitude: latitude, longitude: longitude, radius: radius, identifier: id)
                }
            }
        }

        public func apply(closure: (_ config: LocationsSensor.Config) -> Void) -> Self {
            closure(self)
            return self
        }

        public func addRegion(
            latitude: Double, longitude: Double, radius: Double, identifier: String
        ) {
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let region = CLCircularRegion(center: center, radius: radius, identifier: identifier)
            self.regions.append(region)
        }

        public func removeRegion(identifier: String) {
            for (index, region) in self.regions.enumerated() {
                if region.identifier == identifier {
                    self.regions.remove(at: index)
                    self.removeRegion(identifier: identifier)
                }
            }
        }
    }

    public override convenience init() {
        self.init(LocationsSensor.Config())
    }

    public init(_ config: LocationsSensor.Config) {
        self.CONFIG = config
        super.init()
        self.initializeDbEngine(config: config)

        // Create tables before setting the delegate to prevent save failures if
        // locationManagerDidChangeAuthorization fires synchronously and triggers start().
        if let engine = self.dbEngine as? SQLiteEngine,
            let queue = engine.getSQLiteInstance()
        {
            try? LocationsData.createTable(queue: queue)
            try? VisitData.createTable(queue: queue)
            try? GeofenceData.createTable(queue: queue)
            try? HeadingData.createTable(queue: queue)
            try? LocationEventData.createTable(queue: queue)
        }

        self.locationManager.delegate = self
        applyHeadingAngleFilter()
        applyDistanceFilter()

        let makeEngine = { (tableName: String) -> Engine in
            Engine.Builder()
                .setPath(config.dbPath)
                .setType(config.dbType)
                .setHost(config.dbHost)
                .setTableName(tableName)
                .build()
        }
        visitEngine = makeEngine(VisitData.databaseTableName)
        geofenceEngine = makeEngine(GeofenceData.databaseTableName)
        headingEngine = makeEngine(HeadingData.databaseTableName)
        eventEngine = makeEngine(LocationEventData.databaseTableName)

        self.syncConfig = DbSyncConfig().apply { c in
            c.debug = config.debug
            c.dispatchQueue = DispatchQueue(
                label: "com.awareframework.ios.sensor.locations.sync.queue")
        }

        if config.debug { print(LocationsSensor.TAG, "Location sensor is created.") }
    }

    public override func start() {
        resetHeadingTimeFilter()
        applyHeadingAngleFilter()

        switch currentAuthorizationStatus {
        case .notDetermined:
            // Request when-in-use authorization initially
            if CONFIG.debug {
                print(
                    LocationsSensor.TAG,
                    "Location service is not authorized. Send an authorization request.")
            }
            locationManager.requestWhenInUseAuthorization()
            return
        case .restricted, .denied:
            // Disable location features
            // disableMyLocationBasedFeatures()
            if CONFIG.debug {
                print(
                    LocationsSensor.TAG,
                    "Location service is restricted or denied. Please check the location sensor setting from Settings.app."
                )
            }
            return
        case .authorizedWhenInUse:
            requestAlwaysAuthorizationIfNeeded()
        case .authorizedAlways:
            // Enable basic location features
            // enableMyWhenInUseFeatures()
            break
        @unknown default:
            break
        }

        if CONFIG.debug { print(LocationsSensor.TAG, "Start location services") }
        self.startLocationServices()

        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(
            withTimeInterval: CONFIG.sampleIntervalSeconds,
            repeats: true,
            block: { (timer) in
                self.saveLocationData()
            })

        postOnMain(name: .actionAwareLocationsStart, object: self)
    }

    private var currentAuthorizationStatus: CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return locationManager.authorizationStatus
        }
        if #unavailable(iOS 14.0) {
            return CLLocationManager.authorizationStatus()
        }
        preconditionFailure("Unsupported iOS version")
    }

    private func requestAlwaysAuthorizationIfNeeded() {
        guard !hasRequestedAlwaysAuthorization else { return }
        hasRequestedAlwaysAuthorization = true
        locationManager.requestAlwaysAuthorization()
    }

    public override func stop() {
        if CONFIG.debug { print(LocationsSensor.TAG, "Stop location services") }
        self.stopLocationServices()
        resetHeadingTimeFilter()
        if let t = self.timer {
            t.invalidate()
            self.timer = nil
        }
        postOnMain(name: .actionAwareLocationsStop, object: self)
    }

    public override func sync(force: Bool = false) {
        if CONFIG.debug { print(LocationsSensor.TAG, "Start database sync") }
        postOnMain(name: .actionAwareLocationsSync, object: self)

        guard let baseConfig = self.syncConfig else { return }
        baseConfig.debug = self.CONFIG.debug

        // Auxiliary table engines are created with the sensor. Refresh their host because clients
        // can apply the upload server later without recreating the LocationsSensor instance.
        [visitEngine, geofenceEngine, headingEngine, eventEngine].forEach {
            $0?.config.host = self.CONFIG.dbHost
        }

        let makeSyncConfig = { (tableName: String) -> DbSyncConfig in
            DbSyncConfig().apply { c in
                c.debug = baseConfig.debug
                c.progressHandler = baseConfig.progressHandler
                c.batchHandler = baseConfig.batchHandler
                c.dispatchQueue = DispatchQueue(
                    label: "com.awareframework.ios.sensor.locations.sync.\(tableName)")
                c.completionHandler = { status, error in
                    var userInfo: [String: Any] = [
                        LocationsSensor.EXTRA_STATUS: status,
                        LocationsSensor.EXTRA_TABLE_NAME: tableName,
                    ]
                    if let e = error { userInfo[LocationsSensor.EXTRA_ERROR] = e }
                    self.postOnMain(
                        name: .actionAwareLocationsSyncCompletion,
                        object: self, userInfo: userInfo)
                }
            }
        }

        dbEngine?.startSync(makeSyncConfig(LocationsData.databaseTableName))
        visitEngine?.startSync(makeSyncConfig(VisitData.databaseTableName))
        geofenceEngine?.startSync(makeSyncConfig(GeofenceData.databaseTableName))
        headingEngine?.startSync(makeSyncConfig(HeadingData.databaseTableName))
        eventEngine?.startSync(makeSyncConfig(LocationEventData.databaseTableName))
    }

    public override func set(label: String) {
        self.CONFIG.label = label
        postOnMain(
            name: .actionAwareLocationsSetLabel,
            object: self,
            userInfo: [LocationsSensor.EXTRA_LABEL: label])
    }

    func startLocationServices() {
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.allowsBackgroundLocationUpdates = true
        applyDistanceFilter()
        // Configure and start the service.
        if #available(iOS 11.0, *) {
            locationManager.showsBackgroundLocationIndicator = false
        }

        if let uwAccuracy = CONFIG.accuracy {
            locationManager.desiredAccuracy = uwAccuracy
        } else {
            if CONFIG.minGpsAccuracy == 0 {
                locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            } else if CONFIG.minGpsAccuracy <= 5.0 {
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
            } else if CONFIG.minGpsAccuracy <= 25.0 {
                locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            } else if CONFIG.minGpsAccuracy <= 100.0 {
                locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            } else if CONFIG.minGpsAccuracy <= 1000.0 {
                locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
            } else if CONFIG.minGpsAccuracy <= 3000.0 {
                locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            } else {
                locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            }
        }

        if self.CONFIG.statusGps {
            locationManager.startUpdatingLocation()
            if self.CONFIG.statusSignificantLocationChanges {
                locationManager.startMonitoringSignificantLocationChanges()
            }
        }

        if self.CONFIG.statusLocationVisit {
            locationManager.startMonitoringVisits()
        }

        if self.CONFIG.statusHeading {
            applyHeadingAngleFilter()
            locationManager.startUpdatingHeading()
        }

        for region in self.CONFIG.regions {
            locationManager.startMonitoring(for: region)
        }
    }

    func stopLocationServices() {
        if self.CONFIG.statusGps {
            locationManager.stopUpdatingLocation()
            if self.CONFIG.statusSignificantLocationChanges {
                locationManager.stopMonitoringSignificantLocationChanges()
            }
        }
        if self.CONFIG.statusLocationVisit {
            locationManager.stopMonitoringVisits()
        }

        if self.CONFIG.statusHeading {
            locationManager.stopUpdatingHeading()
        }

        for region in self.CONFIG.regions {
            locationManager.stopMonitoring(for: region)
        }
    }

    private func applyHeadingAngleFilter() {
        locationManager.headingFilter =
            CONFIG.headingFilterDegrees == 0
            ? kCLHeadingFilterNone
            : CONFIG.headingFilterDegrees
    }

    /// Change the distance filter (meters; 0 turns it off) while the sensor runs: Core Location
    /// reports locations, and with `saveAll = false` locations are saved, after moves of this
    /// distance from now on. A negative or infinite value is ignored. Call it on the main thread.
    public func setDistanceFilter(_ meters: CLLocationDistance) {
        CONFIG.distanceFilter = meters   // validated by the config
        applyDistanceFilter()
    }

    private func applyDistanceFilter() {
        locationManager.distanceFilter =
            CONFIG.distanceFilter == 0 ? kCLDistanceFilterNone : CONFIG.distanceFilter
    }

    func resetHeadingTimeFilter() {
        headingTimeFilter.reset()
    }

    func saveLocationData() {
        let now = Date()
        if let lastLocation = self.LAST_DATA {
            // check timeout (second)
            let currentTimestamp = now.timeIntervalSince1970
            let lastLocationTimestamp = lastLocation.timestamp.timeIntervalSince1970
            if self.CONFIG.debug {
                print(
                    LocationsSensor.TAG,
                    "Passed         : \(Int64(currentTimestamp - lastLocationTimestamp)) second")
                print(LocationsSensor.TAG, "Expiration Time: \(self.CONFIG.expirationTime) second")
            }
            if Int64(currentTimestamp - lastLocationTimestamp) < self.CONFIG.expirationTime {
                if self.CONFIG.debug { print(LocationsSensor.TAG, "Save the last location data") }
                self.saveLocations([lastLocation], eventTime: now)
            } else {
                // self.locationManager.requestLocation()
                if let currentLocation = self.locationManager.location {
                    self.saveLocations([currentLocation], eventTime: now)
                    self.LAST_DATA = currentLocation
                    if self.CONFIG.debug {
                        print(LocationsSensor.TAG, "Get a new location data due to data expiration")
                        print(LocationsSensor.TAG, currentLocation.debugDescription)
                    }
                }
            }
        } else {
            if let currentLocation = self.locationManager.location {
                self.saveLocations([currentLocation], eventTime: now)
                self.LAST_DATA = currentLocation
                if self.CONFIG.debug { print(LocationsSensor.TAG, "Get a new location data ") }
            } else {
                if self.CONFIG.debug { print(LocationsSensor.TAG, "Location data is lost") }
            }
        }
    }

    private func saveLocationEvent(
        type: String,
        message: String = "",
        error: Error? = nil,
        status: CLAuthorizationStatus? = nil
    ) {
        var data = LocationEventData()
        data.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        data.label = self.CONFIG.label
        data.eventType = type
        data.message = message
        if let error {
            let nsError = error as NSError
            data.errorDomain = nsError.domain
            data.errorCode = nsError.code
            if data.message.isEmpty {
                data.message = nsError.localizedDescription
            }
        }
        let resolvedStatus = status ?? currentAuthorizationStatus
        data.authorizationStatus = Self.authorizationStatusLabel(resolvedStatus)
        if #available(iOS 14.0, *) {
            data.accuracyAuthorization = Self.accuracyAuthorizationLabel(
                locationManager.accuracyAuthorization)
        }
        if let location = self.LAST_DATA ?? self.locationManager.location {
            data.latitude = location.coordinate.latitude
            data.longitude = location.coordinate.longitude
            data.horizontalAccuracy = location.horizontalAccuracy
        }
        save([data], to: eventEngine)
        postOnMain(
            name: .actionAwareLocationsEvent,
            object: self,
            userInfo: data.toDictionary())
    }

    private static func authorizationStatusLabel(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }

    @available(iOS 14.0, *)
    private static func accuracyAuthorizationLabel(_ authorization: CLAccuracyAuthorization)
        -> String
    {
        switch authorization {
        case .fullAccuracy: return "fullAccuracy"
        case .reducedAccuracy: return "reducedAccuracy"
        @unknown default: return "unknown"
        }
    }
}

extension LocationsSensor: CLLocationManagerDelegate {

    @available(iOS 14.0, *)
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if self.CONFIG.debug { print(#function) }
        handleAuthorizationStatus(manager.authorizationStatus)
    }

    public func locationManager(
        _ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
    ) {
        if self.CONFIG.debug { print(#function) }
        handleAuthorizationStatus(status)
    }

    private func handleAuthorizationStatus(_ status: CLAuthorizationStatus) {
        saveLocationEvent(
            type: "authorization_changed",
            message: Self.authorizationStatusLabel(status),
            status: status)
        switch status {
        case .authorizedAlways:
            self.start()
        case .authorizedWhenInUse:
            requestAlwaysAuthorizationIfNeeded()
            self.start()
        default:
            break
        }
    }

    public func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {

        guard !locations.isEmpty else { return }

        if self.CONFIG.debug {
            print(LocationsSensor.TAG, #function, locations.debugDescription)
        }

        self.LAST_DATA = locations.last

        if self.CONFIG.saveAll {
            self.saveLocations(locations, eventTime: nil)
            return
        }

        // The first location, then only moves of `saveDistanceThreshold` from the last saved one
        let significantLocations = self.significantLocationsSinceLastSave(from: locations)
        if !significantLocations.isEmpty {
            self.saveLocations(significantLocations, eventTime: nil)
        }
    }

    /// The distance a location has to be from the last saved one to be saved (`saveAll = false`):
    /// `distanceFilter` when set, otherwise `minGpsAccuracy` (at least 1 m)
    var saveDistanceThreshold: CLLocationDistance {
        CONFIG.distanceFilter > 0 ? CONFIG.distanceFilter : max(CONFIG.minGpsAccuracy, 1)
    }

    private func significantLocationsSinceLastSave(from locations: [CLLocation]) -> [CLLocation] {
        let threshold = saveDistanceThreshold
        var referenceLocation = self.lastSavedLocation
        var significantLocations: [CLLocation] = []

        for location in locations {
            guard let reference = referenceLocation else {
                significantLocations.append(location)
                referenceLocation = location
                continue
            }

            if location.distance(from: reference) >= threshold {
                significantLocations.append(location)
                referenceLocation = location
            }
        }

        return significantLocations
    }

    func saveLocations(_ locations: [CLLocation], eventTime: Date?) {
        var dataArray = [LocationsData]()
        for location in locations {
            var data = LocationsData()
            if let uwEventTime = eventTime {
                data.timestamp = Int64(uwEventTime.timeIntervalSince1970 * 1000)
            } else {
                data.timestamp = Int64(location.timestamp.timeIntervalSince1970 * 1000)
            }
            data.altitude = location.altitude
            data.latitude = location.coordinate.latitude
            data.longitude = location.coordinate.longitude
            data.course = location.course
            data.speed = location.speed
            data.verticalAccuracy = location.verticalAccuracy
            data.horizontalAccuracy = location.horizontalAccuracy
            data.label = self.CONFIG.label
            data.floor = location.floor?.level ?? 0
            dataArray.append(data)
            if let observer = CONFIG.sensorObserver {
                observer.onLocationChanged(data: data)
            }
        }
        save(dataArray, to: dbEngine)
        if let location = locations.last {
            self.lastSavedLocation = location
        }
        postOnMain(name: .actionAwareLocations, object: self)
    }

    public func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        // TODO: development
        if self.CONFIG.debug { print(visit) }

        var data = VisitData()
        data.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        data.horizontalAccuracy = visit.horizontalAccuracy
        data.latitude = visit.coordinate.latitude
        data.longitude = visit.coordinate.longitude
        data.departure = Int64(visit.departureDate.timeIntervalSince1970 * 1000.0)
        data.arrival = Int64(visit.arrivalDate.timeIntervalSince1970 * 1000.0)
        data.label = self.CONFIG.label

        let location = CLLocation.init(
            latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude)
        let geocoder = CLGeocoder.init()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            if let e = error {
                if self.CONFIG.debug { print(e) }
            }
            if let marks = placemarks {
                if marks.count > 0 {
                    let placemark = marks[0]
                    let address =
                        "\(placemark.subThoroughfare ?? ""), \(placemark.thoroughfare ?? ""), \(placemark.locality ?? ""), \(placemark.subLocality ?? ""), \(placemark.administrativeArea ?? ""), \(placemark.postalCode ?? ""), \(placemark.country ?? "")"
                    data.address = address

                    if let name = placemark.name {
                        data.name = name
                    }
                }
            }

            if self.CONFIG.debug { print(data) }

            self.save([data], to: self.visitEngine)
            if let observer = self.CONFIG.sensorObserver {
                observer.onVisit(data: data)
            }
            self.postOnMain(
                name: .actionAwareLocationsVisit,
                object: self,
                userInfo: [LocationsSensor.EXTRA_LABEL: visit])
        }

    }

    public func locationManager(
        _ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading
    ) {
        let heading = SendableHeading(value: newHeading)
        if Thread.isMainThread {
            receiveHeading(heading)
        } else {
            let sensor = WeakReference(self)
            DispatchQueue.main.async {
                sensor.value?.receiveHeading(heading)
            }
        }
    }

    private func receiveHeading(_ heading: SendableHeading) {
        self.LAST_HEADING = heading.value
        headingTimeFilter.submit(
            heading,
            minimumInterval: CONFIG.headingFilterSeconds)
    }

    private func processHeading(_ newHeading: CLHeading) {
        // needleView.transform = CGAffineTransform.init(rotationAngle: CGFloat(-newHeading.magneticHeading) * CGFloat.pi / 180)
        var data = HeadingData()
        data.magneticHeading = newHeading.magneticHeading
        data.trueHeading = newHeading.trueHeading
        data.headingAccuracy = newHeading.headingAccuracy
        data.x = newHeading.x
        data.y = newHeading.y
        data.z = newHeading.z
        data.timestamp = Int64(newHeading.timestamp.timeIntervalSince1970 * 1000.0)
        if let observer = self.CONFIG.sensorObserver {
            observer.onHeadingChanged(data: data)
        }
        postOnMain(
            name: .actionAwareLocationsHeadingChanged,
            object: self,
            userInfo: [LocationsSensor.EXTRA_LABEL: newHeading])
        save([data], to: headingEngine)
        if self.CONFIG.debug { print(data) }
    }

    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if self.CONFIG.debug { print(region) }
        var data = GeofenceData()
        data.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        data.onEntry = true
        data.identifier = region.identifier
        if let location = manager.location {
            data.verticalAccuracy = location.verticalAccuracy
            data.horizontalAccuracy = location.horizontalAccuracy
            data.latitude = location.coordinate.latitude
            data.longitude = location.coordinate.longitude
        }
        data.label = self.CONFIG.label
        if let observer = self.CONFIG.sensorObserver {
            observer.onEnterRegion(data: data)
        }
        save([data], to: geofenceEngine)
        postOnMain(
            name: .actionAwareLocationsEnterRegion,
            object: self,
            userInfo: [LocationsSensor.EXTRA_LABEL: region.identifier])

    }

    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if self.CONFIG.debug { print(region) }
        var data = GeofenceData()
        data.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        data.onExit = true
        data.identifier = region.identifier
        data.label = self.CONFIG.label
        if let location = manager.location {
            data.verticalAccuracy = location.verticalAccuracy
            data.horizontalAccuracy = location.horizontalAccuracy
            data.latitude = location.coordinate.latitude
            data.longitude = location.coordinate.longitude
        }
        if let observer = self.CONFIG.sensorObserver {
            observer.onExitRegion(data: data)
        }
        save([data], to: geofenceEngine)
        postOnMain(
            name: .actionAwareLocationsExitRegion,
            object: self,
            userInfo: [LocationsSensor.EXTRA_LABEL: region.identifier])
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if self.CONFIG.debug { print(error) }
        saveLocationEvent(type: "failed", error: error)
    }

    public func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        if self.CONFIG.debug { print(#function) }
        saveLocationEvent(type: "paused", message: "Core Location paused location updates")
    }

    public func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        if self.CONFIG.debug { print(#function) }
        saveLocationEvent(type: "resumed", message: "Core Location resumed location updates")
    }

}
