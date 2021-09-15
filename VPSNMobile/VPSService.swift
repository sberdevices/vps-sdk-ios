

import ARKit

public protocol VPSServiceDelegate: AnyObject {
    func serialcount(doned: Int)
    /// Returns an instance of the response
    func positionVPS(pos: ResponseVPSPhoto)
    /// Returns a server error
    func error(err: NSError)
    /// Sending request, debug func
    func sending()
}
/// optional implementation
public extension VPSServiceDelegate {
    func sending() {}
}

public struct Settings {
    /// Url server of your object
    let url: String
    /// Specific object's id
    let locationID: String
    /// Get features on a server
    let recognizeType: RecognizeType
    /// url for downloading neuro
    let neuroLink: String
    /// Time of interpolation
    public var animationTime: Float = 1 {
        didSet {
            animationTime = clamped(animationTime, minValue: 0.1, maxValue: Float.infinity)
        }
    }
    /// Delay between sending photos
    public var sendPhotoDelay: TimeInterval = 6.0 {
        didSet {
            sendPhotoDelay = clamped(sendPhotoDelay, minValue: 2, maxValue: TimeInterval.infinity)
        }
    }
    /// Distance to which position interpolation works
    public var distanceForInterp: Float = 4 {
        didSet {
            distanceForInterp = clamped(distanceForInterp, minValue: 0.1, maxValue: Float.infinity)
        }
    }
    /// gpsAccuracyBarrier
    public var gpsAccuracyBarrier = 20.0 {
        didSet {
            gpsAccuracyBarrier = clamped(gpsAccuracyBarrier, minValue: 0, maxValue: Double.infinity)
        }
    }
    /// number of serial requests
    public var serialCount = 5 {
        didSet {
            serialCount = clamped(serialCount, minValue: 1, maxValue: Int.max)
        }
    }
    /// The timeout interval of the request.
    public var timeOutDuration: TimeInterval = 5 {
        didSet {
            timeOutDuration = clamped(timeOutDuration, minValue: 1.0, maxValue: TimeInterval.infinity)
        }
    }
    /// The timeout of  first request
    public var firstRequestDelay: TimeInterval = 2 {
        didSet {
            firstRequestDelay = clamped(firstRequestDelay, minValue: 0.0, maxValue: TimeInterval.infinity)
        }
    }
    /// Maximum angle when interpolation works
    public var angleForInterp: Float = 45 {
        didSet {
            distanceForInterp = clamped(distanceForInterp, minValue: 0.1, maxValue: 360)
        }
    }
    /// set GeoReferencing manualy
    public let customGeoReference: GeoReferencing?
    ///
    /// - Parameters:
    ///   - url: Url server of your object
    ///   - locationID: Specific object's id
    ///   - recognizeType: Get features on a server
    ///   - neuroLink: url for downloading neuro
    ///   - customGeoReference: set customGeoReference
    public init(url: String,
                locationID: String,
                recognizeType: RecognizeType,
                neuroLink: String = "https://testable1.s3pd01.sbercloud.ru/vpsmobiletflite/230421/hfnet_i8_960.tflite",
                customGeoReference: GeoReferencing? = nil) {
        self.url = url
        self.locationID = locationID
        self.recognizeType = recognizeType
        self.neuroLink = neuroLink
        self.customGeoReference = customGeoReference
    }
}

public protocol VPSService {
    var settings: Settings { get }
    var converterGPS: ConverterGPS { get }
    /// Send of not gps
    var gpsUsage: Bool { get set }
    /// Turns of or onf the recalibration mode
    var onlyForceMode: Bool { get set }
    /// Enable serial localize when localize falled
    var serialLocalizeEnabled: Bool { get set }
    /// start tracking position
    func start()
    /// stop tracking position
    func stop()
    /// get the last position if available
    func getLatestPose()
    /// Set custom position
    func setupMock(mock: ResponseVPSPhoto)
    /// Set for vps can update position
    func frameUpdated()
    
    func sendUIImage(image: UIImage)
}

public class VPSBuilder {
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
    ///   - settings: Settings
    ///   - gpsUsage: Send of not gps
    ///   - onlyForceMode: Turns of or onf the recalibration mode
    ///   - delegate: VPSServiceDelegate
    ///   - success: Return vps module
    ///   - failure:
    ///   - serialLocalizeEnabled: Enable serial localize when localize falled
    ///   - loadingProgress: Shows download progress within 0...1
    public static func initializeVPS(arsession: ARSession,
                                     settings: Settings,
                                     gpsUsage: Bool = false,
                                     onlyForceMode: Bool = false,
                                     serialLocalizeEnabled: Bool = false,
                                     delegate: VPSServiceDelegate?,
                                     success: ((VPSService) -> Void)?,
                                     loadingProgress: ((Double) -> Void)? = nil,
                                     failure: ((NSError) -> Void)? = nil) {
        let vps = VPS(arsession: arsession,
                      gpsUsage: gpsUsage,
                      onlyForceMode: onlyForceMode,
                      serialLocalizeEnabled: serialLocalizeEnabled,
                      settings: settings)
        vps.delegate = delegate
        switch settings.recognizeType {
        case .server:
            success?(vps)
        case .mobile:
            vps.neuroInit {
                success?(vps)
            } downProgr: { (dProgr) in
                loadingProgress?(dProgr)
            } failure: { (err) in
                print("err", err)
                failure?(err)
            }
        }
    }
}

/// struct for responce
public struct ResponseVPSPhoto {
    /// false or not status localize
    public var status: Bool
    public var posX: Float
    public var posY: Float
    public var posZ: Float
    public var posRoll: Float
    public var posPitch: Float
    public var posYaw: Float
    public var gps: GPSResponse?
    public var compass: CompassResponse?
    var id: String?
    
    public struct CompassResponse {
        public var heading: Double
        public init(heading: Double) {
            self.heading = heading
        }
    }
    
    public struct GPSResponse {
        public var lat: Double
        public var long: Double
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
    public init(status: Bool, posX: Float, posY: Float, posZ: Float, posRoll: Float, posPitch: Float, posYaw: Float, gps: GPSResponse? = nil, compass: CompassResponse? = nil) {
        self.status = status
        self.posX = posX
        self.posY = posY
        self.posZ = posZ
        self.posRoll = posRoll
        self.posPitch = posPitch
        self.posYaw = posYaw
        self.gps = gps
        self.compass = compass
    }
}
/// Get features on a server or device
public enum RecognizeType {
    case server
    case mobile
}
