import Foundation
import com_awareframework_ios_core
import GRDB

public struct HeadingData: BaseDbModelSQLite {
    public var id: Int64?
    public var timestamp: Int64 = 0
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String = ""
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1

    public static let databaseTableName = "ios_heading"

    public var magneticHeading:  Double = 0
    public var trueHeading:      Double = 0
    public var headingAccuracy:  Double = 0
    public var x: Double = 0
    public var y: Double = 0
    public var z: Double = 0

    public init() {}

    public init(_ dict: Dictionary<String, Any>) {
        timestamp       = dict["timestamp"] as? Int64 ?? 0
        label           = dict["label"] as? String ?? ""
        deviceId        = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        magneticHeading = dict["magneticHeading"] as? Double ?? 0
        trueHeading     = dict["trueHeading"] as? Double ?? 0
        headingAccuracy = dict["headingAccuracy"] as? Double ?? 0
        x = dict["x"] as? Double ?? 0
        y = dict["y"] as? Double ?? 0
        z = dict["z"] as? Double ?? 0
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
                t.column("magneticHeading", .double).notNull()
                t.column("trueHeading", .double).notNull()
                t.column("headingAccuracy", .double).notNull()
                t.column("x", .double).notNull()
                t.column("y", .double).notNull()
                t.column("z", .double).notNull()
            }
        }
    }

    public func toDictionary() -> Dictionary<String, Any> {
        return [
            "id": id ?? -1,
            "timestamp": timestamp,
            "deviceId": deviceId,
            "label": label,
            "magneticHeading": magneticHeading,
            "trueHeading": trueHeading,
            "headingAccuracy": headingAccuracy,
            "x": x,
            "y": y,
            "z": z
        ]
    }
}
