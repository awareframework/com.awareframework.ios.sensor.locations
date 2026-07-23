import Foundation
import com_awareframework_ios_core
import GRDB

public struct LocationEventData: BaseDbModelSQLite {
    public var id: Int64?
    public var timestamp: Int64 = 0
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String = ""
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1

    public static let databaseTableName = "ios_location_events"

    public var eventType: String = ""
    public var message: String = ""
    public var errorDomain: String = ""
    public var errorCode: Int = 0
    public var authorizationStatus: String = ""
    public var accuracyAuthorization: String = ""
    public var latitude: Double = 0
    public var longitude: Double = 0
    public var horizontalAccuracy: Double = 0

    public init() {}

    public init(_ dict: Dictionary<String, Any>) {
        timestamp = dict["timestamp"] as? Int64 ?? 0
        label = dict["label"] as? String ?? ""
        deviceId = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        eventType = dict["eventType"] as? String ?? ""
        message = dict["message"] as? String ?? ""
        errorDomain = dict["errorDomain"] as? String ?? ""
        errorCode = dict["errorCode"] as? Int ?? 0
        authorizationStatus = dict["authorizationStatus"] as? String ?? ""
        accuracyAuthorization = dict["accuracyAuthorization"] as? String ?? ""
        latitude = dict["latitude"] as? Double ?? 0
        longitude = dict["longitude"] as? Double ?? 0
        horizontalAccuracy = dict["horizontalAccuracy"] as? Double ?? 0
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
                t.column("eventType", .text).notNull()
                t.column("message", .text).notNull()
                t.column("errorDomain", .text).notNull()
                t.column("errorCode", .integer).notNull()
                t.column("authorizationStatus", .text).notNull()
                t.column("accuracyAuthorization", .text).notNull()
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("horizontalAccuracy", .double).notNull()
            }
        }
    }

    public func toDictionary() -> Dictionary<String, Any> {
        [
            "id": id ?? -1,
            "timestamp": timestamp,
            "deviceId": deviceId,
            "label": label,
            "eventType": eventType,
            "message": message,
            "errorDomain": errorDomain,
            "errorCode": errorCode,
            "authorizationStatus": authorizationStatus,
            "accuracyAuthorization": accuracyAuthorization,
            "latitude": latitude,
            "longitude": longitude,
            "horizontalAccuracy": horizontalAccuracy
        ]
    }
}
