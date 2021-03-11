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
class VPS: NSObject {
    private let locationManager = CLLocationManager()
    ///what location are we scanning
    var locationType:String!
    var arsession: ARSession
    ///Need for sending request
    var timer:Timer?
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
    
    var force = true
    var failerCount = 0
    var firstLocalize = true
    var mock = false
    
    var recognizeType:RecognizeType
    
    var neuro: Neuro?

    var onlyForceMode = false
    
    ///Send the next request only after receiving a response
    var getAnswer = true
    
    var network: NetVPSService
    
    ///Need for image processing
    var queue = DispatchQueue(label: "VPSQueue")
    
    weak var delegate:VPSDelegate? = nil
    
    init(arsession: ARSession,
         url: String,
         locationID:String,
         onlyForce:Bool,
         recognizeType:RecognizeType) {
        self.arsession = arsession
        self.network = Network(url: url, locationID: locationID)
        self.recognizeType = recognizeType
        super.init()
        onlyForceMode = onlyForce
        self.locationType = locationID
        if Settings.gpsUsage {
            attemptLocationAccess()
        }
        if recognizeType == .mobile {
            neuroInit()
        }
    }
    ///Init for Tensorflow. If the model is not on the device, then it will be downloaded from the server
    func neuroInit() {
        if let url = modelPath(name: "hfnet_i8_960.tflite", folder: ModelsFolder.name) {
            Neuro.newInstance(path: url.path) { result in
                switch result {
                case let .success(segmentator):
                    self.neuro = segmentator
                case .error(_):
                    print("Failed to initialize.")
                }
            }
        } else {
            network.downloadNeuroModel { (url) in
                if let path = saveModel(from: url, name: "hfnet_i8_960.tflite", folder: ModelsFolder.name) {
                    Neuro.newInstance(path: path.path) { result in
                        switch result {
                        case let .success(segmentator):
                            self.neuro = segmentator
                        case .error(_):
                            print("Failed to initialize.")
                        }
                    }
                } else {
                    print("cant save model")
                }
            } downProgr: { (pr) in
                self.delegate?.downloadProgr(value: pr)
            } failure: { (err) in
                self.delegate?.error(err: err)
            }

        }
    }
    
    func start() {
        mock = false
        if timer == nil {
            let timer = Timer(timeInterval: Settings.sendPhotoDelay,
                              target: self,
                              selector: #selector(updateTimer),
                              userInfo: nil,
                              repeats: true)
            RunLoop.current.add(timer, forMode: .common)
            timer.tolerance = 0.1
            self.timer = timer
            self.timer?.fire()
        } else {
            print("таймер создан")
        }
    }
    
    func stop() {
        self.timer?.invalidate()
        self.timer = nil
        firstLocalize = true
        force = true
        self.getAnswer = true
    }
    
    func getLatestPose() {
        if let last = lastpose {
            delegate?.positionVPS(pos: last)
        }
    }
    
    func setupMock(mock:ResponseVPSPhoto) {
        self.timer?.invalidate()
        self.timer = nil
        self.mock = true
        self.getAnswer = true
        guard let frame = arsession.currentFrame else {
            return
        }
        photoTransform = frame.camera.transform
        setupWorld(from: mock, transform: frame.camera.transform)
        delegate?.positionVPS(pos: mock)
    }
    
    func forceLocalize(enabled: Bool) {
        onlyForceMode = enabled
        if !enabled {
            force = true
        }
    }
    
    ///Used for interpolation capability
    func frameUpdated() {
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
    
    @objc func updateTimer() {
        if getAnswer {
            queue.async {
                self.sendRequest()
            }
        }
    }
    func sendRequest() {
        switch recognizeType {
        case .server:
            sendPhoto()
        case .mobile:
            sendNeuro()
        }
    }
    func sendUIImage(im:UIImage) {
        self.timer?.invalidate()
        self.timer = nil
        force = true
        sendPhotoMock(im: im)
    }
    
    func sendPhoto(){
        guard let frame = arsession.currentFrame else {
            return
        }
        guard var up = self.getPosition(frame: frame, orient: 0) else {
            getAnswer = true
            return
        }
        let image = UIImage.createFromPB(pixelBuffer: frame.capturedImage)!
            .convertToGrayScale(withSize: CGSize(width: 960, height: 540))!
        up.image = image
        DispatchQueue.main.async {
            self.delegate?.sending()
        }
        network.uploadPanPhoto(photo: up, success: { (ph) in
            self.getAnswer = true
            if self.mock { return }
            if ph.status {
                self.failerCount = 0
                if !self.onlyForceMode {
                    self.force = false
                }
                self.firstLocalize = false
                self.delegate?.positionVPS(pos: ph)
                self.setupWorld(from: ph, transform: self.photoTransform)
            } else {
                self.delegate?.positionVPS(pos: ph)
                self.failerCount += 1
            }
        }) { (error) in
            self.delegate?.error(err: error)
            self.getAnswer = true
        }
    }
    ///Forms a request for the current frame
    func getPosition(frame: ARFrame?, orient: Int) -> UploadVPSPhoto? {
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
        
        getAnswer = false
        if !firstLocalize {
            if failerCount >= 3 {
                force = true
            }
        }
        
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
                                instrinsicsFX: intrinsics.fx,
                                instrinsicsFY: intrinsics.fy,
                                instrinsicsCX: intrinsics.cx,
                                instrinsicsCY: intrinsics.cy,
                                image: nil,
                                forceLocalization: force)
        if Settings.gpsUsage, canGetCorrectGPS() {
            guard let loc = locationManager.location else { return nil }
            if loc.horizontalAccuracy > Settings.gpsAccuracyBarrier {
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
    
    
    func sendNeuro() {
        guard let frame = arsession.currentFrame else {
            return
        }
        guard let up = self.getPosition(frame: frame, orient: 1) else {
            getAnswer = true
            return
        }
        self.neuro?.run(buf: frame.capturedImage, completion: { result in
            switch result {
            case let .success(segmentationResult):
//                print("s",segmentationResult.global_descriptor.first)
                DispatchQueue.main.async {
                    self.delegate?.sending()
                }
                self.network.uploadNeuroPhoto(photo: up,
                                              coreml: segmentationResult.global_descriptor,
                                              keyPoints: segmentationResult.keypoints,
                                              scores: segmentationResult.scores,
                                              desc: segmentationResult.local_descriptors) { (ph) in
                    
                    if self.mock { return }
                    if ph.status {
                        self.failerCount = 0
                        if !self.onlyForceMode {
                            self.force = false
                        }
                        self.firstLocalize = false
                        self.delegate?.positionVPS(pos: ph)
                        self.setupWorld(from: ph, transform: self.photoTransform)
                        self.getAnswer = true
                    } else {
                        self.delegate?.positionVPS(pos: ph)
                        self.failerCount += 1
                        self.getAnswer = true
                    }
                } failure: { (NSError) in
                    self.getAnswer = true
                }

            case let .error(error):
                print("Everything was wrong, \(error)!")
            }
        })
    }
    ///delete timer for fixing memory leak
    func deInit(){
        self.timer?.invalidate()
        self.timer = nil
    }
    
    /// Change WorldOrigin
    /// - Parameters:
    ///   - ph: Position to change
    ///   - transform: Position when the photo was sent
    func setupWorld(from ph:ResponseVPSPhoto, transform: simd_float4x4) {
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
            if leng > Settings.distanceForInterp {
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
        let all:Float = Settings.animationTime
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
    
    private func attemptLocationAccess() {
        guard CLLocationManager.locationServicesEnabled() else {
            return
        }
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.delegate = self
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            if #available(iOS 14.0, *) {
                if locationManager.accuracyAuthorization == .reducedAccuracy {
                    locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "TemporaryAuth") { (err) in
                        if err == nil {
                            self.locationManager.startUpdatingLocation()
                            self.locationManager.startUpdatingHeading()
                        }
                    }
                    return
                }
            }
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
            
        default:
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    private func canGetCorrectGPS() -> Bool {
        if #available(iOS 14.0, *) {
            let authStatus = locationManager.authorizationStatus
            let accAuth = locationManager.accuracyAuthorization
            return authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse && accAuth == .fullAccuracy
        } else {
            let authStatus = CLLocationManager.authorizationStatus()
            return authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse
        }
    }
    
    func sendPhotoMock(im:UIImage) {
        guard var up = self.getPosition(frame: nil, orient: 1) else {
            getAnswer = true
            return
        }
        let frame = arsession.currentFrame
        if let fr = frame {
            photoTransform = fr.camera.transform
        }
        
        switch recognizeType {
        case .server:
            let image = im.convertToGrayScale(withSize: CGSize(width: 960, height: 540))!
            up.image = image
            DispatchQueue.main.async {
                self.delegate?.sending()
            }
            network.uploadPanPhoto(photo: up, success: { (ph) in
                self.delegate?.positionVPS(pos: ph)
                if frame != nil {
                    self.setupWorld(from: ph, transform: self.photoTransform)
                }
            }) { (error) in
                self.getAnswer = true
                self.delegate?.error(err: error)
            }
        case .mobile:
            self.neuro?.run(useImage: im, completion: { (result) in
                switch result {
                case let .success(segmentationResult):
                    DispatchQueue.main.async {
                        self.delegate?.sending()
                    }
                    self.network.uploadNeuroPhoto(photo: up,
                                                  coreml: segmentationResult.global_descriptor,
                                                  keyPoints: segmentationResult.keypoints,
                                                  scores: segmentationResult.scores,
                                                  desc: segmentationResult.local_descriptors) { (ph) in
                        self.getAnswer = true
                        self.delegate?.positionVPS(pos: ph)
                        if frame != nil {
                            self.setupWorld(from: ph, transform: self.photoTransform)
                        }

                    } failure: { (NSError) in
                        self.getAnswer = true
                        self.delegate?.error(err: NSError)
                    }

                case let .error(error):
                    self.getAnswer = true
                    print("Everything was wrong, \(error)!")
                }
            })
        }
    }
}

extension VPS: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations
    locations: [CLLocation]) {
    }
    
    func locationManager(_ manager: CLLocationManager,
                    didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if #available(iOS 14.0, *) {
                if locationManager.accuracyAuthorization == .reducedAccuracy {
                    locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "TemporaryAuth") { (err) in
                        if err == nil {
                            self.locationManager.startUpdatingLocation()
                            self.locationManager.startUpdatingHeading()
                        }
                    }
                    return
                }
            }
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        default:
            locationManager.stopUpdatingLocation()
            locationManager.stopUpdatingHeading()
        }
    }
    
    func locationManager(_ manager: CLLocationManager,
                   didFailWithError error: Error) {
    }
}
