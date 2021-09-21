//
//  VPSNMobileTests.swift
//  VPSNMobileTests
//
//  Created by Eugene Smolyakov on 24.03.2021.
//

import XCTest
@testable import VPSNMobile
import ARKit

class VPSNMobileTests: XCTestCase {
    
    func testSetSettings() {
        var settings:Settings = Settings(url: "",
                                         locationID: "",
                                         recognizeType: .server)
        settings.animationTime = 0.2
        XCTAssertEqual(settings.animationTime, 0.2)
        settings.animationTime = -1
        XCTAssertEqual(settings.animationTime, 0.1)
        
        settings.sendPhotoDelay = 3
        XCTAssertEqual(settings.sendPhotoDelay, 3)
        settings.sendPhotoDelay = -1
        XCTAssertEqual(settings.sendPhotoDelay, 2.0)
        
        settings.distanceForInterp = -1
        XCTAssertEqual(settings.distanceForInterp, 0.1)
        
        settings.gpsAccuracyBarrier = 30
        XCTAssertEqual(settings.gpsAccuracyBarrier, 30)
    }
    
    func testInitServerVPS() {
        let exp = expectation(description: "vps-" + #function)
        var vpsService:VPSService?
        let settings:Settings = Settings(url: "",
                                         locationID: "",
                                         recognizeType: .server)
        VPSBuilder.initializeVPS(arsession: ARSession(), settings: settings, gpsUsage: true, onlyForceMode: true, delegate: nil) { (service) in
            vpsService = service
            XCTAssertNotNil(vpsService)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testDownloadNeuroAndInit() throws {
        if let url = modelPath(name: "hfnet_i8_960.tflite", folder: ModelsFolder.name) {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "model exist")
            try FileManager.default.removeItem(at: url)
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "model removed")
        }
        let exp1 = expectation(description: "exp1-" + #function)
        var vpsService:VPSService?
        let settings:Settings = Settings(url: "",
                                         locationID: "",
                                         recognizeType: .mobile)
        VPSBuilder.initializeVPS(arsession: ARSession(),
                                 settings: settings,
                                 gpsUsage: true,
                                 onlyForceMode: true,
                                 delegate: nil) { (service) in
            vpsService = service
            XCTAssertNotNil(vpsService, "vpsService not nil")
            exp1.fulfill()
        } loadingProgress: { (double) in
            print("progress",double)
        } failure: { (err) in
            
        }
        
        waitForExpectations(timeout: 25, handler: nil)
    }
    
    func testInitMobileVPS() {
        let exp1 = expectation(description: "exp1-" + #function)
        var vpsService:VPSService?
        var time:TimeInterval = 25
        if modelPath(name: "hfnet_i8_960.tflite", folder: ModelsFolder.name) != nil {
            time = 2
        }
        let settings:Settings = Settings(url: "",
                                         locationID: "",
                                         recognizeType: .mobile)
        VPSBuilder.initializeVPS(arsession: ARSession(),
                                 settings: settings,
                                 gpsUsage: true,
                                 onlyForceMode: true,
                                 delegate: nil) { (service) in
            vpsService = service
            XCTAssertNotNil(vpsService, "vpsService not nil")
            exp1.fulfill()
        } loadingProgress: { (double) in
            print("progress",double)
        } failure: { (err) in
            
        }
        waitForExpectations(timeout: time, handler: nil)
    }
    
    func testFailNeuroInit() throws {
        guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first,
              let writePath = NSURL(fileURLWithPath: path).appendingPathComponent(ModelsFolder.name) else {
            XCTFail()
            return
        }
        try? FileManager.default.createDirectory(atPath: writePath.path, withIntermediateDirectories: true)
        let file = writePath.appendingPathComponent("hfnet_i8_960.tflite")
        if (FileManager.default.fileExists(atPath: file.path)){
            try FileManager.default.removeItem(at: file)
        }
        let sample = Data(count: 10)
        try sample.write(to: file)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        
        let exp1 = expectation(description: "exp1-" + #function)
        let settings:Settings = Settings(url: "",
                                         locationID: "",
                                         recognizeType: .mobile)
        VPSBuilder.initializeVPS(arsession: ARSession(),
                                 settings: settings,
                                 gpsUsage: true,
                                 onlyForceMode: true,
                                 delegate: nil) { (service) in
            
        } loadingProgress: { (double) in
            print("progress",double)
        } failure: { (err) in
            exp1.fulfill()
            print("err",err)
        }
        waitForExpectations(timeout: 1) { (err) in
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    
    func testDefaultConf() {
        let conf = VPSBuilder.getDefaultConfiguration()
        #if targetEnvironment(simulator)
        XCTAssertNil(conf)
        #else
        XCTAssertNotNil(conf)
        #endif
    }
    
    func testInitPublicStruct() {
        let gps = ResponseVPSPhoto.GPSResponse(lat: 1, long: 1)
        let resp = ResponseVPSPhoto(status: true, posX: 1, posY: 1, posZ: 1, posRoll: 1, posPitch: 1, posYaw: 1)
        XCTAssertNotNil(gps)
        XCTAssertNotNil(resp)
    }
}
