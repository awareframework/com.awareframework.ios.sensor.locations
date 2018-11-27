import XCTest
import com_awareframework_ios_sensor_locations

class Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }
    
    func testConfig(){
        
        let statusGps = false;
        let frequencyGps:   Double = 100;
        let minGpsAccuracy: Double = 100;
        let expirationTime: Int64  = 100;
        let saveAll = true;
        
        var config = Dictionary<String,Any>()
        config["statusGps"]    = statusGps
        config["frequencyGps"] = frequencyGps
        config["minGpsAccuracy"] = minGpsAccuracy
        config["expirationTime"] = expirationTime
        config["saveAll"] = saveAll
        
        // default
        var sensor = LocationsSensor.init()
        XCTAssertEqual(sensor.CONFIG.statusGps, true)
        XCTAssertEqual(sensor.CONFIG.frequencyGps, 180)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy, 150)
        XCTAssertEqual(sensor.CONFIG.expirationTime, 300)
        XCTAssertEqual(sensor.CONFIG.saveAll, false)
        
        // apply
        sensor = LocationsSensor.init(LocationsSensor.Config().apply{config in
            config.statusGps = statusGps
            config.frequencyGps = frequencyGps
            config.minGpsAccuracy = minGpsAccuracy
            config.expirationTime = expirationTime
            config.saveAll = saveAll
        })
        XCTAssertEqual(sensor.CONFIG.statusGps,      statusGps)
        XCTAssertEqual(sensor.CONFIG.frequencyGps,   frequencyGps)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy, minGpsAccuracy)
        XCTAssertEqual(sensor.CONFIG.expirationTime, expirationTime)
        XCTAssertEqual(sensor.CONFIG.saveAll,        saveAll)
        
        // init with dictionary
        sensor = LocationsSensor.init(LocationsSensor.Config(config))
        XCTAssertEqual(sensor.CONFIG.statusGps,      statusGps)
        XCTAssertEqual(sensor.CONFIG.frequencyGps,   frequencyGps)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy, minGpsAccuracy)
        XCTAssertEqual(sensor.CONFIG.expirationTime, expirationTime)
        XCTAssertEqual(sensor.CONFIG.saveAll,        saveAll)
        
        // set
        sensor = LocationsSensor.init()
        sensor.CONFIG.set(config: config)
        XCTAssertEqual(sensor.CONFIG.statusGps,      statusGps)
        XCTAssertEqual(sensor.CONFIG.frequencyGps,   frequencyGps)
        XCTAssertEqual(sensor.CONFIG.minGpsAccuracy, minGpsAccuracy)
        XCTAssertEqual(sensor.CONFIG.expirationTime, expirationTime)
        XCTAssertEqual(sensor.CONFIG.saveAll,        saveAll)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
}
