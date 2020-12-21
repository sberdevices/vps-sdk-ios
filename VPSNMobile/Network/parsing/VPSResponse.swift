//
//  VPSResponse.swift
//  VPS
//
//  Created by Eugene Smolyakov on 03.09.2020.
//  Copyright © 2020 ES. All rights reserved.
//

import Foundation

func parseVPSResponse(from d: NSDictionary) -> ResponseVPSPhoto? {

    guard let attributes = d["attributes"] as? NSDictionary else { return nil }
    guard let location = attributes["location"] as? NSDictionary else { return nil }
    guard let relative = location["relative"] as? NSDictionary else { return nil }
    
    let pitch = parseDouble(relative, key: "pitch")
    let roll = parseDouble(relative, key: "roll")
    let yaw = parseDouble(relative, key: "yaw")
    let x = parseDouble(relative, key: "x")
    let y = parseDouble(relative, key: "y")
    let z = parseDouble(relative, key: "z")
    let status = parseString(attributes, for: "status")
    var resp = ResponseVPSPhoto(status: status == "done",
                                posX: Float(x),
                                posY: Float(y),
                                posZ: Float(z),
                                posRoll: Float(roll),
                                posPitch: Float(pitch),
                                posYaw: Float(yaw))
    if let gps = location["gps"] as? NSDictionary {
        let lat = parseDouble(gps, key: "latitude")
        let long = parseDouble(gps, key: "longitude")
        resp.gps = ResponseVPSPhoto.gpsResponse(lat: lat, long: long)
    } else {
        print("no gps")
    }
    return resp
}
