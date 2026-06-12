import Foundation
import com_awareframework_ios_core
import GRDB

public struct LocationsData: BaseDbModelSQLite {
    public var id: Int64?
    public var timestamp: Int64 = 0
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String = ""
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1

    public static let databaseTableName = "ios_locations"

    public var latitude:  Double = 0
    public var longitude: Double = 0
    public var course:    Double = 0
    public var speed:     Double = 0
    public var altitude:  Double = 0
    public var horizontalAccuracy: Double = 0
    public var verticalAccuracy:   Double = 0
    public var floor: Int = 0

    public init() {}

    public init(_ dict: Dictionary<String, Any>) {
        timestamp           = dict["timestamp"] as? Int64 ?? 0
        label               = dict["label"] as? String ?? ""
        deviceId            = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        latitude            = dict["latitude"] as? Double ?? 0
        longitude           = dict["longitude"] as? Double ?? 0
        course              = dict["course"] as? Double ?? 0
        speed               = dict["speed"] as? Double ?? 0
        altitude            = dict["altitude"] as? Double ?? 0
        horizontalAccuracy  = dict["horizontalAccuracy"] as? Double ?? 0
        verticalAccuracy    = dict["verticalAccuracy"] as? Double ?? 0
        floor               = dict["floor"] as? Int ?? 0
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
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("course", .double).notNull()
                t.column("speed", .double).notNull()
                t.column("altitude", .double).notNull()
                t.column("horizontalAccuracy", .double).notNull()
                t.column("verticalAccuracy", .double).notNull()
                t.column("floor", .integer).notNull()
            }
        }
    }

    public func toDictionary() -> Dictionary<String, Any> {
        return [
            "id": id ?? -1,
            "timestamp": timestamp,
            "deviceId": deviceId,
            "label": label,
            "latitude": latitude,
            "longitude": longitude,
            "course": course,
            "speed": speed,
            "altitude": altitude,
            "horizontalAccuracy": horizontalAccuracy,
            "verticalAccuracy": verticalAccuracy,
            "floor": floor
        ]
    }
}
