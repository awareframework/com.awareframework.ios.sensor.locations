# AWARE: Locations

[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

The locations sensor provides the best location estimate for the users’ current location, automatically. The location data is provided by [Core Location](https://developer.apple.com/documentation/corelocation).

## Requirements
iOS 13 or later.

## Installation

Add the package with Swift Package Manager:

- Package URL: `https://github.com/awareframework/com.awareframework.ios.sensor.locations.git`
- Product: `com.awareframework.ios.sensor.locations`
- Module: `import com_awareframework_ios_sensor_locations`

See the [core package README](https://github.com/awareframework/com.awareframework.ios.core#installation) for the Xcode, `Package.swift` and command-line installation steps.

**Info.plist:** `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription`. To record in the background, also add the `location` background mode (`UIBackgroundModes`).

## Public Functions

### LocationsSensor

+ `init(config:LocationsSensor.Config?)`: Initializes the locations sensor with the optional configuration.
+ `start()`: Starts the locations sensor with the optional configuration.
+ `stop()`: Stops the service.

### LocationsSensor.Config

Class to hold the configuration of the sensor.

#### Fields

+ `sensorObserver: LocationsObserver?`: Callback for live data updates. (default = `nil`)
+ `sampleIntervalSeconds: Double`: How often to check the location, in seconds. By default, every 180 seconds. (default = `180`)
+ `minGpsAccuracy: Double`: The target GPS accuracy, in meters. When `accuracy` is `nil`, it selects `CLLocationManager.desiredAccuracy` (`0` = best for navigation, ≤ 5 = best, ≤ 25 = ten meters, ≤ 100 = hundred meters, ≤ 1000 = kilometer, otherwise three kilometers). When `saveAll` is `false`, it is also the minimum distance, in meters, from the last saved location for a new location to be saved. Negative values are ignored. (default = `100`)
+ `accuracy: CLLocationAccuracy?`: Sets `CLLocationManager.desiredAccuracy` directly (e.g. `kCLLocationAccuracyBest`). When set, it overrides the accuracy derived from `minGpsAccuracy`. (default = `nil`)
+ `distanceFilter: Double`: The minimum distance, in meters, before Core Location sends another standard location update. Set `0` to disable distance filtering. (default = `0`)
+ `expirationTime: Int64`: the amount of elapsed time, in seconds, until the location is considered outdated. By default, 300 seconds. (default = `300`)
+ `saveAll: Bool`: Whether to save all the location updates or not. (default = `true`)
+ `statusGps: Bool`: Whether to use continuous GPS location tracking via `startUpdatingLocation`. (default = `true`)
+ `statusLocationVisit: Bool`: Whether to monitor visits (`startMonitoringVisits`). Visits are saved to the `ios_visit` table, with a reverse-geocoded address when available. (default = `true`)
+ `statusHeading: Bool`: Whether to record compass heading updates (`startUpdatingHeading`). Headings are saved to the `ios_heading` table. (default = `false`)
+ `headingFilterDegrees: CLLocationDegrees`: The minimum heading change, in degrees, before Core Location delivers another heading update. Set `0` to disable the angle filter. Values below `0` or above `360` are ignored. (default = `10`)
+ `headingFilterSeconds: TimeInterval`: The minimum elapsed time, in seconds, between saved heading updates. Set `0` to disable the time filter. Negative values are ignored. (default = `1`)

+ `statusSignificantLocationChanges: Bool`: Whether to also use significant-location-change monitoring as a background wake-up/recovery mechanism. Standard location updates remain enabled when `statusGps` is `true`. (default = `true`)
+ `enabled: Bool`: Sensor is enabled or not. (default = `false`)
+ `debug: Bool`: Enable/disable logging. (default = `false`)
+ `label: String`: Label for the data. (default = `""`)
+ `deviceId: String`: Id of the device that will be associated with the events and the sensor. (default = `""`)
+ `dbEncryptionKey: String?`: Encryption key for the database. (default = `nil`)
+ `dbType: DatabaseType`: Which db engine to use for saving data. (default = `.none`)
+ `dbPath: String`: Path of the database. (default = `"aware_locations"`)
+ `dbHost: String?`: Host for syncing the database. (default = `nil`)

The first heading after starting the sensor is saved immediately. Later updates received inside `headingFilterSeconds` are coalesced, and only the latest pending heading is saved at the end of the interval. The original heading measurement timestamp is preserved.

## Broadcasts

### Fired Broadcasts

+ `LocationsSensor.ACTION_AWARE_LOCATIONS`: fired when new location available.
+ `LocationsSensor.ACTION_AWARE_GPS_LOCATION_ENABLED`: fired when GPS location is active.
+ `LocationsSensor.ACTION_AWARE_GPS_LOCATION_DISABLED`: fired when GPS location disabled.

### Received Broadcasts

+ `LocationsSensor.ACTION_AWARE_LOCATIONS_START`: received broadcast to start the sensor.
+ `LocationsSensor.ACTION_AWARE_LOCATIONS_STOP`: received broadcast to stop the sensor.
+ `LocationsSensor.ACTION_AWARE_LOCATIONS_SYNC`: received broadcast to send sync attempt to the host.
+ `LocationsSensor.ACTION_AWARE_LOCATIONS_SET_LABEL`: received broadcast to set the data label. Label is expected in the `LocationsSensor.EXTRA_LABEL` field of the intent extras.

## Data Representations

### Locations Data

Contains the locations profiles.

| Field              | Type   | Description                                                     |
| ------------------ | ------ | --------------------------------------------------------------- |
| latitude           | Double | The latitude in degrees.                                        |
| longitude          | Double | The longitude in degrees.                                       |
| course             | Double | The direction in which the device is traveling, measured in degrees and relative to due north. |
| speed              | Double | The instantaneous speed of the device, measured in meters per second. |
| altitude           | Double | The altitude, measured in meters.                               |
| floor              | Int    | The logical floor of the building in which the user is located. |
| horizontalAccuracy | Double | The radius of uncertainty for the location, measured in meters. |
| verticalAccuracy   | Double | The accuracy of the altitude value, measured in meters.         |
| deviceId           | String | AWARE device UUID                                               |
| label              | String | Customizable label. Useful for data calibration or traceability |
| timestamp          | Int64  | Unixtime milliseconds since 1970                                |
| timezone           | Int    | Timezone of the device                                          |
| os                 | String | Operating system of the device (e.g., ios)                      |
| jsonVersion        | Int    | JSON schema version                                             |

### Heading Data

Contains compass/heading data.

| Field           | Type   | Description                                                     |
| --------------- | ------ | --------------------------------------------------------------- |
| magneticHeading | Double | The heading (in degrees) relative to magnetic north.            |
| trueHeading     | Double | The heading (in degrees) relative to true north.                |
| headingAccuracy | Double | The maximum deviation (in degrees) between reported and true heading. |
| x               | Double | The geomagnetic data (x-axis) measured in microteslas.          |
| y               | Double | The geomagnetic data (y-axis) measured in microteslas.          |
| z               | Double | The geomagnetic data (z-axis) measured in microteslas.          |
| deviceId        | String | AWARE device UUID                                               |
| label           | String | Customizable label. Useful for data calibration or traceability |
| timestamp       | Int64  | Unixtime milliseconds since 1970                                |
| timezone        | Int    | Timezone of the device                                          |
| os              | String | Operating system of the device (e.g., ios)                      |
| jsonVersion     | Int    | JSON schema version                                             |

### Location Event Data

Contains Core Location lifecycle events, including authorization changes, failures, and pause/resume callbacks.

| Field                 | Type   | Description                                                     |
| --------------------- | ------ | --------------------------------------------------------------- |
| eventType             | String | Event type: `authorization_changed`, `failed`, `paused`, or `resumed`. |
| message               | String | Human-readable event detail.                                    |
| errorDomain           | String | Error domain for failure events.                                |
| errorCode             | Int    | Error code for failure events.                                  |
| authorizationStatus   | String | Current Core Location authorization status.                     |
| accuracyAuthorization | String | Current accuracy authorization on iOS 14 and later.             |
| latitude              | Double | Last known latitude, if available.                              |
| longitude             | Double | Last known longitude, if available.                             |
| horizontalAccuracy    | Double | Last known horizontal accuracy, if available.                   |
| deviceId              | String | AWARE device UUID                                               |
| label                 | String | Customizable label. Useful for data calibration or traceability |
| timestamp             | Int64  | Unixtime milliseconds since 1970                                |
| timezone              | Int    | Timezone of the device                                          |
| os                    | String | Operating system of the device (e.g., ios)                      |
| jsonVersion           | Int    | JSON schema version                                             |

## Example Usage
```swift
// To initialize the sensor
let locationSensor = LocationsSensor.init(LocationsSensor.Config().apply { config in
    config.sensorObserver = Observer()
    config.debug = true
    config.dbType = .sqlite
    // more configuration...
})
// To start the sensor
locationSensor?.start()

// To stop the sensor
locationSensor?.stop()
```

```swift
class Observer:LocationsObserver {
    func onLocationChanged(data: LocationsData) {
    // your code here
    }
}
```

## Author

Yuuki Nishiyama (The University of Tokyo), nishiyama@csis.u-tokyo.ac.jp

## Related Links
- [ Apple | Core Location](https://developer.apple.com/documentation/corelocation)
- [ Apple | CLLocation](https://developer.apple.com/documentation/corelocation/cllocation)

## License
Copyright (c) 2025 AWARE Mobile Context Instrumentation Middleware/Framework (http://www.awareframework.com)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
