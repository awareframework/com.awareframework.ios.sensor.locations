import Foundation
import com_awareframework_ios_core
import GRDB

public struct GeofenceData: BaseDbModelSQLite {
    public var id: Int64?
    public var timestamp: Int64 = 0
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String = ""
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1

    public static let databaseTableName = "geofenceData"

    public var horizontalAccuracy: Double = 0
    public var verticalAccuracy:   Double = 0
    public var latitude:  Double = 0
    public var longitude: Double = 0
    public var onExit:  Bool = false
    public var onEntry: Bool = false
    public var targetLatitude:  Double = 0
    public var targetLongitude: Double = 0
    public var targetRadius:    Double = 0
    public var identifier: String = ""

    public init() {}

    public init(_ dict: Dictionary<String, Any>) {
        timestamp          = dict["timestamp"] as? Int64 ?? 0
        label              = dict["label"] as? String ?? ""
        deviceId           = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        horizontalAccuracy = dict["horizontalAccuracy"] as? Double ?? 0
        verticalAccuracy   = dict["verticalAccuracy"] as? Double ?? 0
        latitude           = dict["latitude"] as? Double ?? 0
        longitude          = dict["longitude"] as? Double ?? 0
        onExit             = dict["onExit"] as? Bool ?? false
        onEntry            = dict["onEntry"] as? Bool ?? false
        identifier         = dict["identifier"] as? String ?? ""
    }

    public static func createTable(queue: DatabaseQueue) throws {
        try queue.write { db in
            try db.create(table: databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("deviceId", .text).notNull()
                t.column("timestamp", .integer).notNull()
                t.column("label", .text).notNull()
                t.column("timezone", .integer).notNull()
                t.column("os", .text).notNull()
                t.column("jsonVersion", .integer).notNull()
                t.column("horizontalAccuracy", .double).notNull()
                t.column("verticalAccuracy", .double).notNull()
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("onExit", .boolean).notNull()
                t.column("onEntry", .boolean).notNull()
                t.column("identifier", .text).notNull()
            }
        }
    }

    public func toDictionary() -> Dictionary<String, Any> {
        return [
            "id": id ?? -1,
            "timestamp": timestamp,
            "deviceId": deviceId,
            "label": label,
            "horizontalAccuracy": horizontalAccuracy,
            "verticalAccuracy": verticalAccuracy,
            "latitude": latitude,
            "longitude": longitude,
            "onExit": onExit,
            "onEntry": onEntry,
            "identifier": identifier
        ]
    }
}
