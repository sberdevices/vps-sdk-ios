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
        XCTAssertEqual(converterGPS.rotateAngl!, -24, accuracy: 5)
        //same point but look back
        let converterGPS2 = getConverter(ph: resp2)
        XCTAssertEqual(converterGPS2.rotateAngl!, -24, accuracy: 5)
    }

    func testThrowsStatusWaiting() {
        let converterGPS = ConverterGPS()
        XCTAssertThrowsError(try converterGPS.convertToXYZ(mapPose: MapPoseVPS(lat: 0, long: 0, course: 0)), " err ") { err in
            XCTAssertEqual(err as! ConverterGPS.Status, ConverterGPS.Status.waiting)
        }
    }
    
    func testConverterToXYZ() throws {
        let converterGPS = getConverter(ph: resp1)
        let new = try converterGPS.convertToXYZ(mapPose: MapPoseVPS(lat: 55.735690, long: 37.531213, course: 63.8))
        XCTAssertNoThrow(new)
        XCTAssertEqual(new.position.x, -9, accuracy: 5, "fail - \(new.position.x)")
        XCTAssertEqual(new.position.y, 22.2, accuracy: 5, "fail - \(new.position.y)")
        XCTAssertEqual(new.position.z, 8, accuracy: 5, "fail - \(new.position.z)")
        XCTAssertEqual(new.rotation.y, -40, accuracy: 2)
    }
    
    func testConverterToGeo() throws {
        let converterGPS = getConverter(ph: resp1)
        let new = try converterGPS.convertToGPS(pose: PoseVPS(pos: SIMD3<Float>(-9,22.2,8), rot: SIMD3<Float>(resp1.posPitch.inRadians(), resp1.posYaw.inRadians(), resp1.posRoll.inRadians())))
        XCTAssertNoThrow(new)
        XCTAssertEqual(new.latitude, 55.735690, accuracy: 0.01, "fail - \(new.latitude)")
        XCTAssertEqual(new.longitude, 37.531213, accuracy: 0.01, "fail - \(new.longitude)")
        XCTAssertEqual(new.course, resp1.compass!.heading, accuracy: 1)
    }
    
    
    
    func getConverter(ph:ResponseVPSPhoto) -> ConverterGPS {
        let converterGPS = ConverterGPS()
        if converterGPS.status == .waiting {
            if let geref = VPS.getGeoref(ph: ph) {
                converterGPS.setGeoreference(geoReferencing: geref)
            } else {
                converterGPS.setStatusUnavalable()
            }

        }
        return converterGPS
    }
}
