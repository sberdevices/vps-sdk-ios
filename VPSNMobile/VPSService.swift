//
//  VPSService.swift
//  secFramework
//
//  Created by Eugene Smolyakov on 04.09.2020.
//  Copyright © 2020 ES. All rights reserved.
//

import ARKit

public protocol VPSServiceDelegate:class {
    func positionVPS(pos: ResponseVPSPhoto)
    func error(err:NSError)
    func sending()
}

public class VPSService {
    var vps:VPS?
    
    /// set delegate to get the position
    public weak var delegate:VPSServiceDelegate? = nil
    
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
    
    public func forceLocalize(enabled: Bool) {
        vps?.forceLocalize(enabled: enabled)
    }
    
    deinit {
        vps?.deInit()
        print("deinit VPSService")
    }
}
/// struct if responce
public struct ResponseVPSPhoto {
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
    }
    
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

public enum RecognizeType {
    case server
    case mobile
}
