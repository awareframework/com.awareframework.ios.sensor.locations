import Foundation
import com_awareframework_ios_core
import GRDB

public struct VisitData: BaseDbModelSQLite {
    public var id: Int64?
    public var timestamp: Int64 = 0
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String = ""
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1

    public static let databaseTableName = "visitData"

    public var horizontalAccuracy: Double = 0
    public var latitude:  Double = 0
    public var longitude: Double = 0
    public var name:      String = ""
    public var address:   String = ""
    public var departure: Int64  = 0
    public var arrival:   Int64  = 0

    public init() {}

    public init(_ dict: Dictionary<String, Any>) {
        timestamp          = dict["timestamp"] as? Int64 ?? 0
        label              = dict["label"] as? String ?? ""
        deviceId           = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        horizontalAccuracy = dict["horizontalAccuracy"] as? Double ?? 0
        latitude           = dict["latitude"] as? Double ?? 0
        longitude          = dict["longitude"] as? Double ?? 0
        name               = dict["name"] as? String ?? ""
        address            = dict["address"] as? String ?? ""
        departure          = dict["departure"] as? Int64 ?? 0
        arrival            = dict["arrival"] as? Int64 ?? 0
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
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("name", .text).notNull()
                t.column("address", .text).notNull()
                t.column("departure", .integer).notNull()
                t.column("arrival", .integer).notNull()
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
            "latitude": latitude,
            "longitude": longitude,
            "name": name,
            "address": address,
            "departure": departure,
            "arrival": arrival
        ]
    }
}
