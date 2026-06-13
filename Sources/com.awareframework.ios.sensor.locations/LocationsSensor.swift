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
}

public protocol LocationsObserver {
    func onLocationChanged(data: LocationsData)
    func onExitRegion(data: GeofenceData)
    func onEnterRegion(data: GeofenceData)
    func onVisit(data: VisitData)
    func onHeadingChanged(data: HeadingData)
}

public class LocationsSensor: AwareSensor {

    public let locationManager = CLLocationManager()

    var visitEngine: Engine? = nil
    var geofenceEngine: Engine? = nil
    var headingEngine: Engine? = nil

    public var CONFIG: LocationsSensor.Config

    public static let TAG = "AWARE::Locations"

    var timer: Timer?

    public var LAST_DATA: CLLocation?

    public var LAST_HEADING: CLHeading?

    /**
     * Fired event: New location available
     */
    public static let ACTION_AWARE_LOCATIONS = "com.awareframework.ios.sensor.locations"

    public static let ACTION_AWARE_LOCATIONS_HEADING_CHANGED =
        "ACTION_AWARE_LOCATIONS_HEADING_CHANGED"

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
        public var statusHeading = true
        public var frequencyGps: Double = 180 {
            didSet {
                if self.frequencyGps <= 0 {
                    print(
                        "[LocationsSensor][Illegal Parameter] The 'frequencyGps' value has to be more than 0. ",
                        "This parameter (\(self.frequencyGps)) is ignored.")
                    self.frequencyGps = oldValue
                }
            }
        }
        public var minGpsAccuracy: Double = 150 {
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

        public var saveAll = false

        public var regions: [CLRegion] = [CLRegion]()

        public var accuracy: CLLocationAccuracy? = nil

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

            if let frequency = config["frequencyGps"] as? Double {
                frequencyGps = frequency
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
        }

        self.locationManager.delegate = self

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

        self.syncConfig = DbSyncConfig().apply { c in
            c.debug = config.debug
            c.dispatchQueue = DispatchQueue(
                label: "com.awareframework.ios.sensor.locations.sync.queue")
        }

        if config.debug { print(LocationsSensor.TAG, "Location sensor is created.") }
    }

    public override func start() {

        switch currentAuthorizationStatus {
        case .notDetermined:
            // Request when-in-use authorization initially
            if CONFIG.debug {
                print(
                    LocationsSensor.TAG,
                    "Location service is not authorized. Send an authorization request.")
            }
            locationManager.requestAlwaysAuthorization()
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
        case .authorizedWhenInUse, .authorizedAlways:
            // Enable basic location features
            // enableMyWhenInUseFeatures()
            break
        @unknown default:
            break
        }

        if CONFIG.debug { print(LocationsSensor.TAG, "Start location services") }
        self.startLocationServices()

        if self.timer == nil {
            self.timer = Timer.scheduledTimer(
                withTimeInterval: CONFIG.frequencyGps,
                repeats: true,
                block: { (timer) in
                    self.saveLocationData()
                })
        }

        self.notificationCenter.post(name: .actionAwareLocationsStart, object: self)
    }

    private var currentAuthorizationStatus: CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return locationManager.authorizationStatus
        }
        return CLLocationManager.authorizationStatus()
    }

    public override func stop() {
        if CONFIG.debug { print(LocationsSensor.TAG, "Stop location services") }
        self.stopLocationServices()
        if let t = self.timer {
            t.invalidate()
            self.timer = nil
        }
        self.notificationCenter.post(name: .actionAwareLocationsStop, object: self)
    }

    public override func sync(force: Bool = false) {
        if CONFIG.debug { print(LocationsSensor.TAG, "Start database sync") }
        self.notificationCenter.post(name: .actionAwareLocationsSync, object: self)

        guard let baseConfig = self.syncConfig else { return }
        baseConfig.debug = self.CONFIG.debug

        let makeSyncConfig = { (tableName: String) -> DbSyncConfig in
            DbSyncConfig().apply { c in
                c.debug = baseConfig.debug
                c.progressHandler = baseConfig.progressHandler
                c.dispatchQueue = DispatchQueue(
                    label: "com.awareframework.ios.sensor.locations.sync.\(tableName)")
                c.completionHandler = { status, error in
                    var userInfo: [String: Any] = [
                        LocationsSensor.EXTRA_STATUS: status,
                        LocationsSensor.EXTRA_TABLE_NAME: tableName,
                    ]
                    if let e = error { userInfo[LocationsSensor.EXTRA_ERROR] = e }
                    self.notificationCenter.post(
                        name: .actionAwareLocationsSyncCompletion,
                        object: self, userInfo: userInfo)
                }
            }
        }

        dbEngine?.startSync(makeSyncConfig(LocationsData.databaseTableName))
        visitEngine?.startSync(makeSyncConfig(VisitData.databaseTableName))
        geofenceEngine?.startSync(makeSyncConfig(GeofenceData.databaseTableName))
        headingEngine?.startSync(makeSyncConfig(HeadingData.databaseTableName))
    }

    public override func set(label: String) {
        self.CONFIG.label = label
        self.notificationCenter.post(
            name: .actionAwareLocationsSetLabel,
            object: self,
            userInfo: [LocationsSensor.EXTRA_LABEL: label])
    }

    func startLocationServices() {
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.distanceFilter = CONFIG.minGpsAccuracy  // In meters.
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
            locationManager.startMonitoringSignificantLocationChanges()
        }

        if self.CONFIG.statusLocationVisit {
            locationManager.startMonitoringVisits()
        }

        if self.CONFIG.statusHeading {
            locationManager.startUpdatingHeading()
        }

        for region in self.CONFIG.regions {
            locationManager.startMonitoring(for: region)
        }
    }

    func stopLocationServices() {
        if self.CONFIG.statusGps {
            locationManager.stopUpdatingLocation()
            locationManager.stopMonitoringSignificantLocationChanges()
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
        switch status {
        case .authorizedAlways:
            self.start()
        case .authorizedWhenInUse:
            self.start()
        default:
            break
        }
    }

    public func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {

        if locations.count > 0 {
            if self.CONFIG.debug {
                print(LocationsSensor.TAG, #function, locations.debugDescription)
            }
            if self.LAST_DATA == nil {
                self.saveLocations(locations, eventTime: nil)
            }
            self.LAST_DATA = locations.last
        }

        if self.CONFIG.saveAll {
            self.saveLocations(locations, eventTime: nil)
        }
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
        dbEngine?.save(dataArray)
        self.notificationCenter.post(name: .actionAwareLocations, object: self)
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

            self.visitEngine?.save([data])
            if let observer = self.CONFIG.sensorObserver {
                observer.onVisit(data: data)
            }
            self.notificationCenter.post(
                name: .actionAwareLocationsVisit,
                object: self,
                userInfo: [LocationsSensor.EXTRA_LABEL: visit])
        }

    }

    public func locationManager(
        _ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading
    ) {
        // TODO: development
        self.LAST_HEADING = newHeading
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
        self.notificationCenter.post(
            name: .actionAwareLocationsHeadingChanged,
            object: self,
            userInfo: [LocationsSensor.EXTRA_LABEL: newHeading])
        headingEngine?.save([data])
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
        geofenceEngine?.save([data])
        self.notificationCenter.post(
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
        geofenceEngine?.save([data])
        self.notificationCenter.post(
            name: .actionAwareLocationsExitRegion,
            object: self,
            userInfo: [LocationsSensor.EXTRA_LABEL: region.identifier])
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if self.CONFIG.debug { print(error) }
    }

}
