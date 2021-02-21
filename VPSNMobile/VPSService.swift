//
//  VPSService.swift
//  secFramework
//
//  Created by Eugene Smolyakov on 04.09.2020.
//  Copyright © 2020 ES. All rights reserved.
//

import ARKit

public protocol VPSServiceDelegate:class {
    ///Returns an instance of the response
    func positionVPS(pos: ResponseVPSPhoto)
    ///Returns a server error
    func error(err:NSError)
    ///Debug use for indicate, that photo sending
    func sending()
    ///Shows download progress within 0...1
    func downloadProgr(value: Double)
}

public struct Settings {
    ///Time of interpolation
    public static var animationTime:Float = 0.5
    ///Вelay between sending photos
    public static var sendPhotoDelay:TimeInterval = 6.0
    ///Distance to which position interpolation works
    public static var distanceForInterp:Float = 4
    ///Send of not gps
    public static var gpsUsage: Bool = true
}

public class VPSService {
    var vps:VPS?
    
    /// set delegate to get the position
    public weak var delegate:VPSServiceDelegate? = nil
    
    /// - Parameters:
    ///   - arsession: Object of ARSession()
    ///   - url: Url server of your object
    ///   - locationID: Specific object's id
    ///   - onlyForce: Turns off the recalibration mode
    ///   - recognizeType: Get features on a server or device
    public init(arsession: ARSession,
                url: String,
                locationID:String,
                onlyForce:Bool = false,
                recognizeType:RecognizeType) {
        setupScene(arsession: arsession,
                   url: url,
                   locationID: locationID,
                   onlyForce: onlyForce,
                   recognizeType:recognizeType)
    }
    /// start tracking position
    public func Start() {
        vps?.start()
    }
    /// stop tracking position
    public func Stop() {
        vps?.stop()
    }
    /// get the last position if available
    public func GetLatestPose() {
        vps?.getLatestPose()
    }
    /// Set custom position
    public func SetupMock(mock:ResponseVPSPhoto) {
        vps?.setupMock(mock: mock)
    }
    /// Set for vps can update position
    public func frameUpdated() {
        vps?.frameUpdated()
    }
    
    public func SendUIImage(im:UIImage) {
        vps?.sendUIImage(im: im)
    }
    ///Turns of or onf the recalibration mode
    public func forceLocalize(enabled: Bool) {
        vps?.forceLocalize(enabled: enabled)
    }
    
    deinit {
        vps?.deInit()
        print("deinit VPSService")
    }
}
/// struct for responce
public struct ResponseVPSPhoto {
    ///false or not status localize
    public var status:Bool
    public var posX: Float
    public var posY: Float
    public var posZ: Float
    public var posRoll: Float
    public var posPitch: Float
    public var posYaw: Float
    public var gps:gpsResponse?
    
    public struct gpsResponse {
        public var lat:Double
        public var long:Double
        public init(lat: Double, long: Double) {
            self.lat = lat
            self.long = long
        }
    }
    
    /// - Parameters:
    ///   - status: false or not status localize
    ///   - posX: x
    ///   - posY: y
    ///   - posZ: z
    ///   - posRoll: roll
    ///   - posPitch: pitch
    ///   - posYaw: yaw
    public init(status: Bool, posX: Float, posY: Float, posZ: Float, posRoll: Float, posPitch: Float, posYaw: Float) {
        self.status = status
        self.posX = posX
        self.posY = posY
        self.posZ = posZ
        self.posRoll = posRoll
        self.posPitch = posPitch
        self.posYaw = posYaw
    }
}
///Get features on a server or device
public enum RecognizeType {
    case server
    case mobile
}
