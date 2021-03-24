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
}

public struct Settings {
    ///Time of interpolation
    public var animationTime:Float = 0.5 {
        didSet {
            animationTime = clamped(animationTime, minValue: 0.5, maxValue: 1.5)
        }
    }
    ///Delay between sending photos
    public var sendPhotoDelay:TimeInterval = 6.0 {
        didSet {
            sendPhotoDelay = clamped(sendPhotoDelay, minValue: 3, maxValue: 10)
        }
    }
    ///Distance to which position interpolation works
    public var distanceForInterp:Float = 4 {
        didSet {
            distanceForInterp = clamped(distanceForInterp, minValue: 0, maxValue: 100)
        }
    }
    ///Send of not gps
    public var gpsUsage: Bool = true
    ///gpsAccuracyBarrier
    public var gpsAccuracyBarrier = 20.0 {
        didSet {
            gpsAccuracyBarrier = clamped(gpsAccuracyBarrier, minValue: 0, maxValue: 100)
        }
    }
    ///Turns of or onf the recalibration mode
    public var onlyForceMode = true
    
    public init() {}
}

public protocol VPSService {
    var settings: Settings { get }
    /// start tracking position
    func Start()
    /// stop tracking position
    func Stop()
    /// get the last position if available
    func GetLatestPose()
    /// Set custom position
    func SetupMock(mock:ResponseVPSPhoto)
    /// Set for vps can update position
    func frameUpdated()
    
    func SendUIImage(im:UIImage)
    
    func setupNewSettings(settings: Settings)
}

public enum VPSBuilder {
    /// Return default configuration if available
    public static func getDefaultConfiguration() -> ARWorldTrackingConfiguration? {
        if !ARWorldTrackingConfiguration.isSupported { return nil }
        let configuration = ARWorldTrackingConfiguration()
        configuration.isAutoFocusEnabled = false
        var format: ARConfiguration.VideoFormat?
        for frm in ARWorldTrackingConfiguration.supportedVideoFormats {
            if frm.imageResolution == CGSize(width: 1920, height: 1080) {
                format = frm
                break
            }
        }
        if let format = format {
            configuration.videoFormat = format
            return configuration
        } else {
            return nil
        }
    }
    ///
    /// - Parameters:
    ///   - arsession: Object of ARSession()
    ///   - url: Url server of your object
    ///   - locationID: Specific object's id
    ///   - onlyForce: Turns off the recalibration mode
    ///   - recognizeType: Get features on a server
    ///   - settings: Settings
    ///   - delegate: delegate
    ///   - success: Return vps module
    ///   - downProgr: Shows download progress within 0...1
    ///   - failure:
    public static func VPSInit(arsession: ARSession,
                               url: String,
                               locationID:String,
                               recognizeType: RecognizeType,
                               settings:Settings,
                               delegate:VPSServiceDelegate?,
                               success: ((VPSService) -> Void)?,
                               downProgr: ((Double) -> Void)?,
                               failure: ((NSError) -> Void)?) {
        let vps =  VPS(arsession: arsession,
                       url: url,
                       locationID: locationID,
                       recognizeType: .server,
                       settings: settings)
        vps.delegate = delegate
        switch recognizeType {
        case .server:
            success?(vps)
        case .mobile:
            vps.neuroInit { (bol) in
                if bol {
                    success?(vps)
                } else {
                    fatalError()
                }
            } downProgr: { (dd) in
                downProgr?(dd)
            } failure: { (err) in
                print("err",err)
                failure?(err)
            }

        }
        
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
