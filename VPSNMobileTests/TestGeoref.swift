//
//  TestGeoref.swift
//  VPSNMobileTests
//
//  Created by Evgeniy Smolyakov on 14.07.2021.
//

import XCTest
@testable import VPSNMobile

class TestGeoref: XCTestCase {

    let resp1 = ResponseVPSPhoto(status: true,
                                 posX: 10.065845,
                                 posY: 22.59946,
                                 posZ: -12.885746,
                                 posRoll: -1.6587431,
                                 posPitch: -4.6485486,
                                 posYaw: -39.89614,
                                 gps: Optional(VPSNMobile.ResponseVPSPhoto.gpsResponse(lat: 55.73578619825994, long: 37.53170440360172)),
                                 compass: Optional(VPSNMobile.ResponseVPSPhoto.compassResponse(heading: 63.8)))
    let resp2 = ResponseVPSPhoto(status: true,
                                 posX: 10.065845,
                                 posY: 22.59946,
                                 posZ: -12.885746,
                                 posRoll: 180,
                                 posPitch: 180,
                                 posYaw: 41,
                                 gps: Optional(VPSNMobile.ResponseVPSPhoto.gpsResponse(lat: 55.73578619825994, long: 37.53170440360172)),
                                 compass: Optional(VPSNMobile.ResponseVPSPhoto.compassResponse(heading: 244)))
    
    func testStatus() {
        let converterGPS = getConverter(ph: resp1)
        XCTAssertTrue(converterGPS.status == .ready)
        var respWithoutcompass = resp1
        respWithoutcompass.compass = nil
        let converterWithoutGPS = getConverter(ph: respWithoutcompass)
        XCTAssertTrue(converterWithoutGPS.status == .unavalable)
    }
    
    func testInitFromUrl() throws {
        let testBundle = Bundle(for: type(of: self))
        let url = testBundle.path(forResource: "test", ofType: "json")!
        let data = try Data(contentsOf: URL(fileURLWithPath: url))
        XCTAssertNoThrow(data)
        let decoded = try JSONDecoder().decode(GeoReferencing.self, from: data)
        XCTAssertNoThrow(decoded)
        
        let georef = GeoReferencing.initFromUrl(url: URL(fileURLWithPath: url))
        XCTAssertNotNil(georef)
    }
    
    func testAngl() {
        //for first point angl equal -24, depends on heading
        let converterGPS = getConverter(ph: resp1)
        XCTAssertEqual(converterGPS.geoReferencing!.rotateAngl, -24, accuracy: 5)
        //same point but look back
        let converterGPS2 = getConverter(ph: resp2)
        XCTAssertEqual(converterGPS2.geoReferencing!.rotateAngl, -24, accuracy: 5)
    }
    
    func testConverterToXYZ() {
        let converterGPS = getConverter(ph: resp1)
        let new = converterGPS.convertToXYZ(geoPoint: (lat: 55.735690, long: 37.531213))!
        XCTAssertEqual(new.x, -9, accuracy: 5, "fail - \(new.x)")
        XCTAssertEqual(new.y, 22.2, accuracy: 5, "fail - \(new.y)")
        XCTAssertEqual(new.z, 8, accuracy: 5, "fail - \(new.z)")
    }
    
    func testConverterToGeo() {
        let converterGPS = getConverter(ph: resp1)
        let new = converterGPS.convertToGPS(point: SIMD3<Double>(-9,22.2,8))!
        
        XCTAssertEqual(new.lat, 55.735690, accuracy: 0.01, "fail - \(new.lat)")
        XCTAssertEqual(new.long, 37.531213, accuracy: 0.01, "fail - \(new.long)")
    }
    
    
    
    func getConverter(ph:ResponseVPSPhoto) -> ConverterGPS {
        let converterGPS = ConverterGPS()
        if converterGPS.status == .waiting {
            if let gps = ph.gps,
               let compass = ph.compass{
                let mapPos = MapPoseVPS(lat: gps.lat,
                                        long: gps.long,
                                        course: compass.heading)
                let poseVPS = PoseVPS(pos: SIMD3(x: Double(ph.posX), y: Double(ph.posY), z: Double(ph.posZ)),
                                      rot: SIMD3<Double>(Double(ph.posPitch.inRadians()),
                                                         Double(ph.posYaw.inRadians()),
                                                         Double(ph.posRoll.inRadians())))
                converterGPS.setGeoreference(geoReferencing: GeoReferencing(geopoint: mapPos, coordinate: poseVPS))
            } else {
                converterGPS.setStatusUnavalable()
            }
        }
        return converterGPS
    }
}
