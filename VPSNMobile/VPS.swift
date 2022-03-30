

import ARKit
import CoreMotion

class VPS {
    enum VPSStatus {
        case fastLocalized
        case normal
        case stoped
    }
    
    var vpsStatus: VPSStatus = .stoped
    
    var clientID:String {
        get {
            let usrd = UserDefaults.standard
            if let value = usrd.string(forKey: "ARClient") {
                return value
            } else {
                let value = UUID().uuidString.lowercased()
                usrd.setValue(value, forKey: "ARClient")
                usrd.synchronize()
                return value
            }
        }
    }
    var sessionId: String = UUID().uuidString.lowercased()
    public var settings: Settings
    public var converterGPS: ConverterGPS
    var gpsUsage: Bool {
        didSet {
            if oldValue {
                locationManager.attemptLocationAccess()
            }
        }
    }
    /// Used for gps tracking
    var locationManager: LocationManagering!
    var arsession: ARSession
    /// Need for sending request
    var timer: TimerManager
    /// Saved last success responce
    var lastpose: ResponseVPSPhoto?
    /// if we have already set the position, it is needed for the reverse transformation
    var simdWorldTransform: simd_float4x4?
    ///motion tracker
    var motionTracker: MotionTrackerService
    
    var motionCorrect = true
    
    /// Unlock interpolation
    var moveWorld = false
    var tickCount: Int = 0
    var array: [simd_float4x4]!
    var currenttick = 0
    
    // max failer count
    let failerConst = 5
    // init with same value above, that first localize was force
    var failerCount = 0 {
        didSet {
            if failerCount >= failerConst {
                vpsStatus = .fastLocalized
                failerCount = 0
                updateSesionId()
                timer.recreate(timeInterval: settings.sendFastPhotoDelay, delegate: self, fired: false)
            }
        }
    }
    
    var neuro: Neuro!
    
    var network: NetVPSService
    
    /// Need for image processing
    var queue = DispatchQueue(label: "VPSQueue")
    
    weak var delegate:VPSServiceDelegate? = nil
    
    init(arsession: ARSession,
         gpsUsage: Bool,
         settings: Settings) {
        self.arsession = arsession
        self.network = Network(settings: settings)
        self.gpsUsage = gpsUsage
        self.settings = settings
        self.locationManager = LocationManager()
        self.timer = TimerManager()
        self.motionTracker = MotionTracker()
        self.timer.delayTime = settings.firstRequestDelay
        if gpsUsage {
            locationManager.attemptLocationAccess()
        }
        self.converterGPS = ConverterGPS()
        if let customGeoref = settings.customGeoReference {
            converterGPS.setGeoreference(geoReferencing: customGeoref)
        }
        neuro = Neuro()
    }
    /// Init for Tensorflow. If the model is not on the device, then it will be downloaded from the server
    func neuroInit(succes: (() -> Void)?,
                   downProgr: ((Double) -> Void)?,
                   failure: ((NSError) -> Void)?) {
        var mnv:URL?
        var msp:URL?
        var progressmnv: Double = 0 {
            didSet {
                downProgr?(progressmnv+progressmsp)
            }
        }
        var progressmsp: Double = 0 {
            didSet {
                downProgr?(progressmnv+progressmsp)
            }
        }
        let neuroGroup = DispatchGroup()
        neuroGroup.enter()
        if let url = modelPath(name: NeuroName.mnv, folder: ModelsFolder.name) {
            mnv = url
            neuroGroup.leave()
        } else {
            network.download(url: settings.neuroLinkmnv){ (url) in
                if let path = saveModel(from: url, name: NeuroName.mnv, folder: ModelsFolder.name) {
                    mnv = path
                } else {
                    let er = makeErr(with: Errors.e2)
                    failure?(er)
                }
                neuroGroup.leave()
            } downProgr: { (pr) in
                progressmnv = pr
            } failure: { (err) in
                failure?(err)
                neuroGroup.leave()
            }
        }
        neuroGroup.enter()
        if let url = modelPath(name: NeuroName.msp, folder: ModelsFolder.name) {
            msp = url
            neuroGroup.leave()
        } else {
            network.download(url: settings.neuroLinkmsp){ (url) in
                if let path = saveModel(from: url, name: NeuroName.msp, folder: ModelsFolder.name) {
                    msp = path
                } else {
                    let er = makeErr(with: Errors.e2)
                    failure?(er)
                }
                neuroGroup.leave()
            } downProgr: { (pr) in
                progressmsp = pr
            } failure: { (err) in
                failure?(err)
                neuroGroup.leave()
            }
        }
        
        neuroGroup.notify(queue: queue) {
            if let mnv = mnv, let msp = msp {
                self.neuro.tfLiteInit(mnv: mnv, msp: msp) {
                    succes?()
                } failure: { err in
                    failure?(err)
                }
            }
        }
    }
    
    func createRequest() {
        guard let frame = arsession.currentFrame else {
            return
        }
        guard var up = self.getPosition(frame: frame,
                                        orient: getOrientation()) else { return }
        switch settings.recognizeType {
        case .server:
            let image = UIImage.createFromPB(pixelBuffer: frame.capturedImage)!
                .rotate(radians: .pi/2)!
                .convertToGrayScale(withSize: CGSize(width: 540, height: 960))!
            up.image = image
            sendRequest(meta: up)
        case .mobile:
            getNeuroData(frame: frame) { (neurodata) in
                up.features = neurodata
                self.sendRequest(meta: up)
            } failure: { (err) in
                self.delegate?.error(err: err)
            }
        }
    }
    
    func sendRequest(meta: UploadVPSPhoto) {
        DispatchQueue.main.async {
            self.delegate?.sending()
        }
        network.singleLocalize(photo: meta) { (ph) in
            if self.vpsStatus == .stoped { return }
            if ph.status,
               let pose = ph.vpsPose {
                self.failerCount = 0
                self.setupWorld(from: pose, transform: meta.photoTransform, vpsSend: ph.vpsSendPose)
                if self.converterGPS.status == .waiting {
                    if let geref = VPS.getGeoref(ph: ph) {
                        self.converterGPS.setGeoreference(geoReferencing: geref)
                    } else {
                        self.converterGPS.setStatusUnavalable()
                    }
                }
                if self.vpsStatus == .fastLocalized {
                    self.vpsStatus = .normal
                    self.timer.recreate(timeInterval: self.settings.sendPhotoDelay, delegate: self, fired: false)
                }
            } else {
                self.failerCount += 1
            }
            self.lastpose = ph
            self.delegate?.positionVPS(pos: ph)
        } failure: { (err) in
            self.delegate?.error(err: err)
        }

    }
    
    ///Forms a request for the current frame
    func getPosition(frame: ARFrame?, orient: Int) -> UploadVPSPhoto? {
        var intrinsics:(fx: Float, fy: Float, cx: Float, cy: Float) =
            (fx: 1592.2678,
             fy: 1592.2678,
             cx: 935.7558,
             cy: 538.8366)
        if let fr = frame {
            intrinsics = (fr.camera.intrinsics.columns.0.x,
                          fr.camera.intrinsics.columns.1.y,
                          fr.camera.intrinsics.columns.2.x,
                          fr.camera.intrinsics.columns.2.y)
        }
        switch orient {
        case 1:
            var intr = intrinsics
            intr.fx = intrinsics.fy
            intr.fy = intrinsics.fx
            intr.cx = intrinsics.cy
            intr.cy = intrinsics.cx
            intrinsics = intr
        default:
            break
        }
        
        var newpos = SCNVector3(0, 0, 0)
        var newangl = SCNVector3(0, 0, 0)
        if let fr = frame {
            let node = SCNNode()
            if let transform = simdWorldTransform {
                node.simdTransform = transform * fr.camera.transform
            } else {
                node.simdTransform = fr.camera.transform
            }
            let or = node.convertVector(SCNVector3(0, 0, 1), to: node.parent)
            let aq = GLKQuaternionMake(Float(node.orientation.x),
                                       Float(node.orientation.y),
                                       Float(node.orientation.z),
                                       Float(node.orientation.w))
            let cq = GLKQuaternionMakeWithAngleAndAxis(.pi/2, or.x, or.y, or.z)
            let q = GLKQuaternionMultiply(cq, aq)
            let final = SCNVector4(x: q.x, y: q.y, z: q.z, w: q.w)
            node.orientation = SCNVector4Make(final.x, final.y, final.z, final.w)
            newpos = node.position
            newangl = node.eulerAngles
        }
        var uploadReq = UploadVPSPhoto(sessionID: self.sessionId,
                                       clientID: self.clientID,
                                       timestamp: Date().timeIntervalSince1970,
                                       jobID: UUID().uuidString.lowercased(),
                                       locationClientCoordSystem: "arkit",
                                       locPosX: newpos.x,
                                       locPosY: newpos.y,
                                       locPosZ: newpos.z,
                                       locPosRoll: newangl.z.inDegrees(),
                                       locPosPitch: newangl.x.inDegrees(),
                                       locPosYaw: newangl.y.inDegrees(),
                                       instrinsicsFX: intrinsics.fx/2,
                                       instrinsicsFY: intrinsics.fy/2,
                                       instrinsicsCX: intrinsics.cx/2,
                                       instrinsicsCY: intrinsics.cy/2,
                                       image: nil,
                                       photoTransform: frame?.camera.transform ?? .init(simd_quatf(angle: 0.1, axis: SIMD3<Float>(0.1,0.1,0.1))))
        if gpsUsage, locationManager.canGetCorrectGPS() {
            guard let loc = locationManager.getLocation() else { return nil }
            if loc.horizontalAccuracy > settings.gpsAccuracyBarrier {
                return nil
            }
            uploadReq.gps = GPS(lat: loc.coordinate.latitude,
                                long: loc.coordinate.longitude,
                                alt: loc.altitude,
                                acc: loc.horizontalAccuracy,
                                timestamp: loc.timestamp.timeIntervalSince1970)
        }
        return uploadReq
    }
    
    public static func getGeoref(ph: ResponseVPSPhoto) -> GeoReferencing? {
        if let gps = ph.gps,
           let compass = ph.compass,
           let pos = ph.vpsPose {
            let mapPos = MapPoseVPS(lat: gps.lat,
                                    long: gps.long,
                                    course: compass.heading)
            let poseVPS = PoseVPS(pos: SIMD3<Float>(x: pos.posX,
                                             y: pos.posY,
                                             z: pos.posZ),
                                  rot: SIMD3<Float>(pos.posPitch,
                                                    pos.posYaw,
                                                    pos.posRoll))
            return GeoReferencing(geopoint: mapPos, coordinate: poseVPS)
        }
        return nil
    }
    
    /// Return neuroData or failure, used async queue
    func getNeuroData(frame: ARFrame? = nil,
                      image: UIImage? = nil,
                      success: ((NeuroData) -> Void)?,
                      failure: ((NSError) -> Void)?) {
        
        self.neuro?.run(buf: frame?.capturedImage,
                        useImage: image,
                        completion: { result in
            switch result {
            case let .success(segmentationResult):
                success?(segmentationResult)
            case let .error(error):
                let er = makeErr(with: Errors.e3)
                DispatchQueue.main.async {
                    failure?(er)
                }
                print("Everything was wrong, \(error)!")
            }
        })
    }
    /// delete timer for fixing memory leak
    deinit {
        timer.invalidateTimer()
    }
    
    /// Change WorldOrigin
    /// - Parameters:
    ///   - ph: Position to change
    ///   - transform: Position when the photo was sent
    func setupWorld(from ph: ResponseVPSPhoto.VPSPose, transform: simd_float4x4, interpolate: Bool = true, vpsSend: ResponseVPSPhoto.VPSPose? = nil) {
        guard arsession.currentFrame != nil,
              !moveWorld else {
                  return
              }
        var transform = transform
        if let sendPose = vpsSend,
           let lastTransform = self.simdWorldTransform{
            let node = SCNNode()
            node.position = SCNVector3(sendPose.posX,sendPose.posY,sendPose.posZ)
            node.eulerAngles = SCNVector3(sendPose.posPitch.inRadians(),
                                          sendPose.posYaw.inRadians(),
                                          sendPose.posRoll.inRadians())
            transform = lastTransform.inverse * node.simdTransform
        }
        
        
        let yangl = getAngleFrom(eulere: SCNVector3(ph.posPitch.inRadians(),
                                                    ph.posYaw.inRadians(),
                                                    ph.posRoll.inRadians()))
        let targetPos = SIMD3<Float>(ph.posX,ph.posY,ph.posZ)
        let myPos = getTransformPosition(from: transform)
        
        if let lastTransform = self.simdWorldTransform {
            let photoTransformWorld = lastTransform * transform
            let photoTransformWorldPosition = getTransformPosition(from: photoTransformWorld)
            let photoTransformWorldEul = getAngleFrom(transform: photoTransformWorld)
            let fangl = SIMD3<Float>(0, -yangl+photoTransformWorldEul, 0)
            let endtransform = getWorldTransform(childPos: targetPos,
                                                 parentPos: photoTransformWorldPosition,
                                                 parentEuler: fangl)
            
            let leng = length(myPos - targetPos)
            let anglAccept = getAngleBetweenTransforms(l: lastTransform, r: endtransform).inDegrees() <= settings.angleForInterp
            let distAcccept = leng <= settings.distanceForInterp
            if anglAccept && distAcccept && interpolate {
                self.interpolate(lastWorldTransform: lastTransform,
                            endtransform: endtransform)
            } else {
                self.arsession.setWorldOrigin(relativeTransform: lastTransform.inverse*endtransform)
                self.simdWorldTransform = endtransform
            }
        } else {
            let cameraangl = getAngleFrom(transform: transform)
            let target = getWorldTransform(childPos: targetPos,
                                           parentPos: myPos,
                                           parentEuler: SIMD3<Float>(0, -yangl+cameraangl, 0))
            self.arsession.setWorldOrigin(relativeTransform: target)
            self.simdWorldTransform = target
        }
    }
    
    /// - Parameters:
    ///   - lastWorldTransform: Last applied transformation
    ///   - endtransform: Target transformation
    func interpolate(lastWorldTransform: simd_float4x4,
                     endtransform: simd_float4x4){
        let all: Float = settings.animationTime
        let t: Float = 1 / 60
        let tick = t / all
        
        let startPos = getTransformPosition(from: lastWorldTransform)
        let endPos = getTransformPosition(from: endtransform)
        
        let fn = SCNNode()
        var arr2 = [simd_float4x4]()
        for t: Float in stride(from: tick, through: 1, by: tick) {
            let orient = simd_slerp(simd_quatf(lastWorldTransform), simd_quatf(endtransform), t)
            let pos = mix(startPos, endPos, t: t)
            fn.position = SCNVector3(pos)
            fn.simdOrientation = orient
            arr2.append(fn.simdWorldTransform)
        }
        array = arr2
        tickCount = arr2.count
        moveWorld = true
        currenttick = 0
    }
    
    func getOrientation() -> Int {
        switch settings.recognizeType {
        case .server:
            return 1
        case .mobile:
            return 1
        }
    }
    
    func updateSesionId() {
        sessionId = UUID().uuidString.lowercased()
    }
}

extension VPS: TimerManagerDelegate {
    func timerFired() {
        if motionCorrect {
            queue.async {
                self.createRequest()
            }
        }
    }
}

extension VPS: MotionTrackerServiceListener {
    func changed(motion: CMDeviceMotion?, error: Error?) {
        guard let deviceMotion = motion else { return }
        var pitch = deviceMotion.attitude.pitch * 180.0 / .pi
        if pitch > 0 {
            pitch = 90 - pitch
        } else {
            pitch += 90
        }
        let correct = pitch <= Const.motionAngle
        if correct != motionCorrect {
            DispatchQueue.main.async {
                self.delegate?.correctMotionAngle(correct: correct)
            }
        }
        motionCorrect = correct
    }
}

extension VPS: VPSService {
    public func start() {
        motionTracker.startTrackingFor(delegate: self)
        vpsStatus = .fastLocalized
        timer.startTimer(timeInterval: settings.sendFastPhotoDelay, delegate: self)
        updateSesionId()
    }
    
    public func stop() {
        motionTracker.stopTrackingFor()
        vpsStatus = .stoped
        timer.invalidateTimer()
        failerCount = 0
    }
    
    public func getLatestPose() {
        if let last = lastpose {
            delegate?.positionVPS(pos: last)
        }
    }
    
    public func setupMock(mock: ResponseVPSPhoto) {
        timer.invalidateTimer()
        guard let frame = arsession.currentFrame,
        let pose = mock.vpsPose else {
            return
        }
        setupWorld(from: pose, transform: frame.camera.transform)
        self.lastpose = mock
        delegate?.positionVPS(pos: mock)
        self.lastpose = mock
        if self.converterGPS.status == .waiting {
            if let geref = VPS.getGeoref(ph: mock) {
                self.converterGPS.setGeoreference(geoReferencing: geref)
            } else {
                self.converterGPS.setStatusUnavalable()
            }
        }
    }
    
    public func sendUIImage(image: UIImage) {
        timer.invalidateTimer()
        
        let frame = arsession.currentFrame
        
        guard var up = self.getPosition(frame: frame,
                                        orient: 1) else { return }
        switch settings.recognizeType {
        case .server:
            let image = image.convertToGrayScale(withSize: CGSize(width: 540, height: 960))!
            up.image = image
            sendRequest(meta: up)
        case .mobile:
            getNeuroData(image: image) { (neurodata) in
                up.features = neurodata
                self.sendRequest(meta: up)
            } failure: { (err) in
                self.delegate?.error(err: err)
            }
        }
    }
    
    public func frameUpdated() {
        guard moveWorld else { return }
        if currenttick < tickCount,
           let wt = simdWorldTransform {
            arsession.setWorldOrigin(relativeTransform: wt.inverse*array[currenttick])
            self.simdWorldTransform = array[currenttick]
            currenttick += 1
        } else {
            moveWorld = false
            currenttick = 0
        }
    }
}
