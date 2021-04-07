//
//  VPS.swift
//  secFramework
//
//  Created by Eugene Smolyakov on 04.09.2020.
//  Copyright © 2020 ES. All rights reserved.
//

import ARKit
protocol VPSDelegate: class {
    func positionVPS(pos: ResponseVPSPhoto)
    func error(err:NSError)
    func sending()
    func downloadProgr(value:Double)
}

class VPS  {
    public var settings: Settings
    var gpsUsage: Bool {
        didSet {
            if oldValue {
                locationManager.attemptLocationAccess()
            }
        }
    }
    ///Turns on or off the recalibration mode
    var onlyForceMode: Bool
    ///Enable serial localize when localize falled
    var serialLocalizeEnabled: Bool
    ///Used for gps tracking
    var locationManager:LocationManagering!
    ///what location are we scanning
    var locationType:String!
    var arsession: ARSession
    ///Need for sending request
    var timer:TimerManager = TimerManager()
    ///need for async setting position
    var photoTransform:simd_float4x4!
    ///Saved last success responce
    var lastpose:ResponseVPSPhoto?
    ///if we have already set the position, it is needed for the reverse transformation
    var simdWorldTransform: simd_float4x4?
    
    ///Unlock interpolation
    var moveWorld = false
    var tickCount:Int = 0
    var array: [simd_float4x4]!
    var currenttick = 0
    
    //max failer count
    let failerConst = 3
    //init with same value above, that first localize was force
    var failerCount = 3
    var needForced: Bool {
        get {
            return failerCount >= failerConst
        }
        set {
            failerCount = newValue ? failerConst : 0
        }
    }
    ///serial request packages
    var serialReqests = [UploadVPSPhoto]()
    
    var neuro: Neuro?
    
    ///Send the next request only after receiving a response
    var getAnswer = true
    
    var network: NetVPSService
    
    ///Need for image processing
    var queue = DispatchQueue(label: "VPSQueue")
    
    weak var delegate:VPSServiceDelegate? = nil
    
    init(arsession: ARSession,
         gpsUsage: Bool,
         onlyForceMode: Bool,
         serialLocalizeEnabled:Bool,
         settings:Settings) {
        self.arsession = arsession
        self.network = Network(url: settings.url, locationID: settings.locationID)
        self.gpsUsage = gpsUsage
        self.onlyForceMode = onlyForceMode
        self.serialLocalizeEnabled = serialLocalizeEnabled
        self.settings = settings
        self.locationType = settings.locationID
        self.locationManager = LocationManager()
        if gpsUsage {
            locationManager.attemptLocationAccess()
        }
    }
    ///Init for Tensorflow. If the model is not on the device, then it will be downloaded from the server
    func neuroInit(succes: (() -> Void)?,
                   downProgr: ((Double) -> Void)?,
                   failure: ((NSError) -> Void)?) {
        if let url = modelPath(name: "hfnet_i8_960.tflite", folder: ModelsFolder.name) {
            Neuro.newInstance(path: url.path) { result in
                switch result {
                case let .success(segmentator):
                    self.neuro = segmentator
                    succes?()
                case .error(_):
                    let er = makeErr(with: Errors.e1)
                    failure?(er)
                }
            }
        } else {
            network.downloadNeuroModel { (url) in
                if let path = saveModel(from: url, name: "hfnet_i8_960.tflite", folder: ModelsFolder.name) {
                    Neuro.newInstance(path: path.path) { result in
                        switch result {
                        case let .success(segmentator):
                            self.neuro = segmentator
                            succes?()
                        case .error(_):
                            let er = makeErr(with: Errors.e1)
                            failure?(er)
                        }
                    }
                } else {
                    let er = makeErr(with: Errors.e2)
                    failure?(er)
                }
            } downProgr: { (pr) in
                downProgr?(pr)
            } failure: { (err) in
                failure?(err)
            }
        }
    }
    
    func createRequest(serial:Bool) {
        guard let frame = arsession.currentFrame else {
            return
        }
        guard var up = self.getPosition(frame: frame,
                                        orient: getOrientation(),
                                        serial: serialLocalizeEnabled) else { return }
        switch settings.recognizeType {
        case .server:
            let image = UIImage.createFromPB(pixelBuffer: frame.capturedImage)!
                .convertToGrayScale(withSize: CGSize(width: 960, height: 540))!
            up.image = image
            if serial {
                createSerialRequest(part: up)
            } else {
                sendRequest(meta: up)
            }
        case .mobile:
            getNeuroData(frame: frame) { (neurodata) in
                up.features = neurodata
                if serial {
                    self.createSerialRequest(part: up)
                } else {
                    self.sendRequest(meta: up)
                }
            } failure: { (err) in
                self.delegate?.error(err: err)
            }
        }
    }
    
    func createSerialRequest(part: UploadVPSPhoto){
        serialReqests.append(part)
        DispatchQueue.main.async {
            self.delegate?.serialcount(doned: self.serialReqests.count)
        }
        if serialReqests.count == settings.serialCount {
            self.getAnswer = false
            network.serialLocalize(reqs: serialReqests) { (ph) in
                if ph.status, let id = ph.id, let intid = Int(id), self.serialReqests.indices.contains(intid), let tr = self.serialReqests[intid].photoTransform {
                    self.needForced = false
                    self.setupWorld(from: ph, transform: tr)
                    self.timer.recreate(timeInterval: self.settings.sendPhotoDelay, delegate: self, fired: false)
                }
                self.getAnswer = true
                self.delegate?.positionVPS(pos: ph)
                self.serialReqests.removeAll()
            } failure: { (err) in
                self.delegate?.error(err: err)
                self.getAnswer = true
                self.serialReqests.removeAll()
            }
        }
    }
    
    func sendRequest(meta:UploadVPSPhoto){
        DispatchQueue.main.async {
            self.delegate?.sending()
        }
        getAnswer = false
        network.singleLocalize(photo: meta) { (ph) in
            if ph.status {
                self.needForced = false
                self.setupWorld(from: ph, transform: self.photoTransform)
            } else {
                self.failerCount += 1
            }
            self.getAnswer = true
            self.delegate?.positionVPS(pos: ph)
        } failure: { (err) in
            self.delegate?.error(err: err)
            self.getAnswer = true
        }

    }
    
    ///Forms a request for the current frame
    func getPosition(frame: ARFrame?, orient: Int, serial: Bool) -> UploadVPSPhoto? {
        var intrinsics:(fx:Float, fy:Float, cx:Float, cy:Float) =
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
        
        let force = needForced || onlyForceMode
        var newpos = SCNVector3(0,0,0)
        var newangl = SCNVector3(0,0,0)
        if !force && frame != nil {
            let node = SCNNode()
            node.simdTransform = frame!.camera.transform
            newpos = node.position
            newangl = node.eulerAngles
        }
        photoTransform = frame?.camera.transform
        var up = UploadVPSPhoto(job_id: UUID().uuidString,
                                locationType: "relative",
                                locationID: locationType,
                                locationClientCoordSystem: "arkit",
                                locPosX: newpos.x,
                                locPosY: newpos.y,
                                locPosZ: newpos.z,
                                locPosRoll: newangl.z,
                                locPosPitch: newangl.x,
                                locPosYaw: newangl.y,
                                imageTransfOrientation: orient,
                                imageTransfMirrorX: false,
                                imageTransfMirrorY: false,
                                instrinsicsFX: intrinsics.fx/2,
                                instrinsicsFY: intrinsics.fy/2,
                                instrinsicsCX: intrinsics.cx/2,
                                instrinsicsCY: intrinsics.cy/2,
                                image: nil,
                                forceLocalization: force,
                                photoTransform: frame?.camera.transform)
        if gpsUsage, locationManager.canGetCorrectGPS(), !(serial && needForced) {
            guard let loc = locationManager.getLocation() else { return nil }
            if loc.horizontalAccuracy > settings.gpsAccuracyBarrier {
                return nil
            }
            up.gps = GPS(lat: loc.coordinate.latitude,
                         long: loc.coordinate.longitude,
                         alt: loc.altitude,
                         acc: loc.horizontalAccuracy,
                         timestamp: loc.timestamp.timeIntervalSince1970)
        }
        return up
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
                let data = NeuroData(coreml: segmentationResult.global_descriptor,
                                     keyPoints: segmentationResult.keypoints,
                                     scores: segmentationResult.scores,
                                     desc: segmentationResult.local_descriptors)
                success?(data)
            case let .error(error):
                let er = makeErr(with: Errors.e3)
                DispatchQueue.main.async {
                    failure?(er)
                }
                print("Everything was wrong, \(error)!")
            }
        })
    }
    ///delete timer for fixing memory leak
    deinit {
        timer.invalidateTimer()
    }
    
    /// Change WorldOrigin
    /// - Parameters:
    ///   - ph: Position to change
    ///   - transform: Position when the photo was sent
    func setupWorld(from ph:ResponseVPSPhoto, transform: simd_float4x4?) {
        guard let transform = transform, arsession.configuration == nil else {
            return
        }
        let yangl = getAngleFrom(eulere: SCNVector3(ph.posPitch*Float.pi/180.0,
                                                    ph.posYaw*Float.pi/180.0,
                                                    ph.posRoll*Float.pi/180.0))
        let targetPos = SIMD3<Float>(ph.posX,ph.posY,ph.posZ)
        let myPos = getTransformPosition(from: transform)
        
        if let lastTransform = self.simdWorldTransform {
            let photoTransformWorld = lastTransform * photoTransform
            let photoTransformWorldPosition = getTransformPosition(from: photoTransformWorld)
            let photoTransformWorldEul = getAngleFrom(transform: photoTransformWorld)
            let fangl = SIMD3<Float>(0,-yangl+photoTransformWorldEul,0)
            let endtransform = getWorldTransform(childPos: targetPos,
                                                 parentPos: photoTransformWorldPosition,
                                                 parentEuler: fangl)
            
            let leng = length(myPos - targetPos)
            if leng > settings.distanceForInterp {
                self.arsession.setWorldOrigin(relativeTransform: lastTransform.inverse*endtransform)
                self.simdWorldTransform = endtransform
            } else {
                interpolate(lastWorldTransform: lastTransform,
                            endtransform: endtransform)
            }
        } else {
            let cameraangl = getAngleFrom(transform: transform)
            let target = getWorldTransform(childPos: targetPos,
                                           parentPos: myPos,
                                           parentEuler: SIMD3<Float>(0,-yangl+cameraangl,0))
            self.arsession.setWorldOrigin(relativeTransform: target)
            self.simdWorldTransform = target
        }
    }
    
    /// - Parameters:
    ///   - lastWorldTransform: Last applied transformation
    ///   - endtransform: Target transformation
    func interpolate(lastWorldTransform:simd_float4x4,
                     endtransform:simd_float4x4){
        let all:Float = settings.animationTime
        let t:Float = 1 / 60
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
    }
    
    func getOrientation() -> Int {
        switch settings.recognizeType {
        case .server:
            return 0
        case .mobile:
            return 1
        }
    }
}

extension VPS: TimerManagerDelegate {
    func timerFired() {
        if getAnswer {
            var serial = false
            if needForced && serialLocalizeEnabled {
                if serialReqests.isEmpty {
                    //create new fast timer for localization
                    timer.recreate(timeInterval: 1.5, delegate: self, fired: false)
                }
                serial = true
            }
            queue.async {
                self.createRequest(serial: serial)
            }
        }
    }
}

extension VPS: VPSService{
    public func Start() {
        timer.startTimer(timeInterval: settings.sendPhotoDelay, delegate: self)
    }
    
    public func Stop() {
        timer.invalidateTimer()
        needForced = true
        self.getAnswer = true
    }
    
    public func GetLatestPose() {
        if let last = lastpose {
            delegate?.positionVPS(pos: last)
        }
    }
    
    public func SetupMock(mock: ResponseVPSPhoto) {
        timer.invalidateTimer()
        self.getAnswer = true
        guard let frame = arsession.currentFrame else {
            return
        }
        photoTransform = frame.camera.transform
        setupWorld(from: mock, transform: frame.camera.transform)
        delegate?.positionVPS(pos: mock)
    }
    
    public func SendUIImage(im: UIImage) {
        timer.invalidateTimer()
        
        let frame = arsession.currentFrame
        if let fr = frame {
            photoTransform = fr.camera.transform
        }
        guard var up = self.getPosition(frame: frame,
                                        orient: 1,
                                        serial: false) else { return }
        switch settings.recognizeType {
        case .server:
            let image = im.convertToGrayScale(withSize: CGSize(width: 540, height: 960))!
            up.image = image
            sendRequest(meta: up)
        case .mobile:
            getNeuroData(image: im) { (neurodata) in
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
