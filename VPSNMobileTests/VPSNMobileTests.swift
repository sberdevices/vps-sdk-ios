//
//  VPSNMobileTests.swift
//  VPSNMobileTests
//
//  Created by Eugene Smolyakov on 24.03.2021.
//

import XCTest
import VPSNMobile

class VPSNMobileTests: XCTestCase {

    func testSetSettings() {
        var settings:Settings = Settings()
        settings.animationTime = 0.1
        XCTAssertEqual(settings.animationTime, 0.5)
        settings.animationTime = 2
        XCTAssertEqual(settings.animationTime, 1.5)
        XCTAssertNotEqual(settings.animationTime, 2)
        
        settings.sendPhotoDelay = 2
        XCTAssertEqual(settings.sendPhotoDelay, 3)
        settings.sendPhotoDelay = 11
        XCTAssertEqual(settings.sendPhotoDelay, 10)
        XCTAssertNotEqual(settings.sendPhotoDelay, 11)
    }

}
