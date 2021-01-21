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
}
class VPS: NSObject {
    private let locationManager = CLLocationManager()
    ///what location are we scanning
    var locationType:String!
    var arsession: ARSession
    var timer:Timer?
    ///need for async setting position
    var photoTransform:SCNMatrix4!
    var lastpose:ResponseVPSPhoto?
    ///if we have already set the position, it is needed for the reverse transformation
    var simdWorldTransform: simd_float4x4?
    var movedWorldTransform: simd_float4x4!
    var rotateWorldTransform: simd_float4x4!
    
    var moveWorld = false
    var tickCount:Float = 0
    
    var force = true
    var failerCount = 0
    var firstLocalize = true
    var mock = false
    
    var recognizeType:RecognizeType
    
    var neuro: Neuro?

    var onlyForceMode = false
    
    var getAnswer = true
    
    var network: NetVPSService
    
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
        attemptLocationAccess()
        if recognizeType == .mobile {
            neuroInit()
        }
    }
    
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
            } failure: { (err) in
                self.delegate?.error(err: err)
            }

        }
    }
    
    func start() {
        mock = false
        if timer == nil {
            let timer = Timer(timeInterval: 6.0,
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
        let camera = SCNNode()
        camera.simdTransform = frame.camera.transform
        setupWorld(from: mock, transform: camera.transform)
    }
    
    func forceLocalize(enabled: Bool) {
        onlyForceMode = enabled
        if !enabled {
            force = true
        }
    }
    
    func frameUpdated() {
        guard moveWorld else { return }
        if tickCount > 0 {
            if tickCount > 15 {
                arsession.setWorldOrigin(relativeTransform: movedWorldTransform)
            } else {
                arsession.setWorldOrigin(relativeTransform: rotateWorldTransform)
            }
            tickCount -= 1
        } else {
            moveWorld = false
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
        force = true
        sendPhoto(im: im)
    }
    
    func sendPhoto(im:UIImage? = nil){
        guard let frame = arsession.currentFrame else {
            return
        }
        var up = getPosition(frame: frame)
        var image:UIImage!
        if let im = im {
            image = im
        } else {
            image = UIImage.createFromPB(pixelBuffer: frame.capturedImage)!
                .convertToGrayScale(withSize: CGSize(width: 960, height: 540))!
        }
        up.image = image
        DispatchQueue.main.async {
            self.delegate?.sending()
        }
        print(up.forceLocalization)
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
    
    func getPosition(frame: ARFrame) -> UploadVPSPhoto {
        
        getAnswer = false
        let camera = SCNNode()
        camera.simdTransform = frame.camera.transform
        if !firstLocalize {
            if failerCount >= 3 {
                force = true
            }
        }
        
        var newpos = SCNVector3(0,0,0)
        var newangl = SCNVector3(0,0,0)
        if !force {
            let node = SCNNode()
            node.simdTransform = camera.simdTransform
            newpos = node.position
            newangl = node.eulerAngles
        }
        photoTransform = camera.transform
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
                                imageTransfOrientation: 0,
                                imageTransfMirrorX: false,
                                imageTransfMirrorY: false,
                                instrinsicsFX: frame.camera.intrinsics.columns.0.x,
                                instrinsicsFY: frame.camera.intrinsics.columns.1.y,
                                instrinsicsCX: frame.camera.intrinsics.columns.2.x,
                                instrinsicsCY: frame.camera.intrinsics.columns.2.y,
                                image: nil,
                                forceLocalization: force)
        if let loc = locationManager.location {
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
        self.neuro?.run(buf: frame.capturedImage, completion: { result in
            switch result {
            case let .success(segmentationResult):
                let up = self.getPosition(frame: frame)
                print("s",segmentationResult.global_descriptor.first)
                self.network.uploadNeuroPhoto(photo: up,
                                              coreml: segmentationResult.global_descriptor,
                                              keyPoints: segmentationResult.keypoints,
                                              scores: segmentationResult.scores,
                                              desc: segmentationResult.local_descriptors) { (ph) in
                    
                    if self.mock { return }
                    if ph.status {
                        self.failerCount = 0
                        self.force = false
                        self.firstLocalize = false
                        self.delegate?.positionVPS(pos: ph)
                        self.setupWorld(from: ph, transform: self.photoTransform)
                    } else {
                        self.delegate?.positionVPS(pos: ph)
                        self.failerCount += 1
                    }
                } failure: { (NSError) in
                    
                }

            case let .error(error):
                print("Everything was wrong, Dude!")
            }
        })
    }
    ///delete timer for fixing memory leak
    func deInit(){
        self.timer?.invalidate()
        self.timer = nil
    }
    
    func setupWorld(from ph:ResponseVPSPhoto, transform: SCNMatrix4) {
        let yangl = self.getAngleFrom(eulere: SCNVector3(ph.posPitch*Float.pi/180.0,
                                                         ph.posYaw*Float.pi/180.0,
                                                         ph.posRoll*Float.pi/180.0))
        let cameraangl = self.getAngleFrom(transform: transform)
        let targetPos = SIMD3<Float>(ph.posX,ph.posY,ph.posZ)
        let myPos = SIMD3<Float>(transform.m41,
                                 transform.m42,
                                 transform.m43)
        let node = SCNNode()
        node.position = SCNVector3(-targetPos)
        let rnode = SCNNode()
        rnode.addChildNode(node)
        rnode.position = SCNVector3(myPos)
        //turn the world to an adjusted angle consisting of the server angle and the user angle
        rnode.eulerAngles = SCNVector3(0,-yangl+cameraangl,0)
        if let tr = self.simdWorldTransform {
            let leng = length(myPos - targetPos)
            if leng > 4 {
                self.arsession.setWorldOrigin(relativeTransform: tr.inverse)
                self.arsession.setWorldOrigin(relativeTransform: node.simdWorldTransform)
                self.simdWorldTransform = node.simdWorldTransform
            } else {
            interpolate(targetangl: yangl,
                        targetpos: targetPos)
            }
        } else {
            self.arsession.setWorldOrigin(relativeTransform: node.simdWorldTransform)
            self.simdWorldTransform = node.simdWorldTransform
        }
    }
    
    func interpolate(targetangl:Float, targetpos:SIMD3<Float>) {
        let transf = arsession.currentFrame!.camera.transform
        let curent = getAngleFrom(transform: transf)
        var dif = curent - targetangl
        if dif < -.pi/2 { dif += .pi }
        if dif > .pi/2 { dif -= .pi }
        
        let targAng = SIMD3<Float>(0,dif,0)

        let all:Float = 0.5
        let t:Float = 1 / 60
        tickCount = all / t
        
        let myPos = SIMD3<Float>(transf[3][0],transf[3][1],transf[3][2])
        let moving = (myPos - targetpos) / tickCount * 2
        let moveN = SCNNode()
        moveN.position = SCNVector3(moving)
        movedWorldTransform = moveN.simdWorldTransform
        
        let orig = SCNNode()
        orig.position = SCNVector3(-targetpos)
        let cameraRot = SCNNode()
        cameraRot.addChildNode(orig)
        cameraRot.position = SCNVector3(targetpos)
        cameraRot.eulerAngles = SCNVector3(targAng/tickCount*2)
        rotateWorldTransform = orig.simdWorldTransform
        
        let fn = SCNNode()
        fn.position = SCNVector3(-targetpos)
        fn.eulerAngles = SCNVector3(0,targetangl,0)
        simdWorldTransform = fn.simdWorldTransform
        
        moveWorld = true
        
    }
    func getAngleFrom(eulere: SCNVector3) -> Float {
        let node = SCNNode()
        node.eulerAngles = eulere
        return getAngleFrom(transform: node.transform)
    }

    func getAngleFrom(transform: SCNMatrix4) -> Float {
        let orientation = SCNVector3(transform.m31, transform.m32, transform.m33)
        return atan2f(orientation.x, orientation.z)
    }
    
    func getAngleFrom(transform: simd_float4x4) -> Float {
        let orientation = SIMD3<Float>(transform[2][0],transform[2][1],transform[2][2])
        return atan2f(orientation.x, orientation.z)
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
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        default:
            locationManager.requestWhenInUseAuthorization()
        }
    }
}

extension VPS: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations
    locations: [CLLocation]) {
    }
    
    func locationManager(_ manager: CLLocationManager,
                    didChangeAuthorization status: CLAuthorizationStatus) {
        print("Authorization status changed to \(status.rawValue)")
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
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
