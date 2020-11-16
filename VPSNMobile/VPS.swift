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
    
    var force = true
    var failerCount = 0
    var firstLocalize = true
    var mock = false
    
    var network:NetVPSService = Network()
    var neuro: Neuro?
    var result: NResult?
    
    weak var delegate:VPSDelegate? = nil
    
    init(arsession: ARSession, location:LocationType) {
        self.arsession = arsession
        super.init()
        self.locationType = getLocationType(location: location)
        attemptLocationAccess()
        Neuro.newInstance { result in
            switch result {
            case let .success(segmentator):
                self.neuro = segmentator
            case .error(_):
                print("Failed to initialize.")
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
        guard let frame = arsession.currentFrame else {
            return
        }
        let camera = SCNNode()
        camera.simdTransform = frame.camera.transform
        setupWorld(from: mock, transform: camera.transform)
    }
    
    @objc func updateTimer() {
        getPosition()
    }
    
    func getPosition() {
        guard let frame = arsession.currentFrame else {
            return
        }
        let camera = SCNNode()
        camera.simdTransform = frame.camera.transform
        if !firstLocalize {
            if failerCount >= 3 {
                force = true
            }
        }
        let ci = CIImage(cvPixelBuffer: frame.capturedImage)
        let image = UIImage(ciImage: ci)
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
                                image: image,
                                forceLocalization: force)
        if let loc = locationManager.location {
            up.gps = GPS(lat: loc.coordinate.latitude,
                         long: loc.coordinate.longitude,
                         alt: loc.altitude,
                         acc: loc.horizontalAccuracy,
                         timestamp: loc.timestamp.timeIntervalSince1970)
        }
        network.uploadPanPhoto(photo: up, success: { (ph) in
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
        }) { (error) in
            self.delegate?.error(err: error)
        }
    }
    ///delete timer for fixing memory leak
    func deInit(){
        self.timer?.invalidate()
        self.timer = nil
        self.neuro = nil
    }
    
    func setupWorld(from ph:ResponseVPSPhoto, transform: SCNMatrix4) {
        let yangl = self.getAngleFrom(eulere: SCNVector3(ph.posPitch*Float.pi/180.0,
                                                         ph.posYaw*Float.pi/180.0,
                                                         ph.posRoll*Float.pi/180.0))
        let cameraangl = self.getAngleFrom(transform: transform)
        let node = SCNNode()
        node.position = SCNVector3(-ph.posX,-ph.posY,-ph.posZ)
        let rnode = SCNNode()
        rnode.addChildNode(node)
        rnode.position = SCNVector3(transform.m41,
                                    transform.m42,
                                    transform.m43)
        //turn the world to an adjusted angle consisting of the server angle and the user angle
        rnode.eulerAngles = SCNVector3(0,-yangl+cameraangl,0)
        
        if let tr = self.simdWorldTransform {
            self.arsession.setWorldOrigin(relativeTransform: tr.inverse)
        }
        self.arsession.setWorldOrigin(relativeTransform: node.simdWorldTransform)
        self.simdWorldTransform = node.simdWorldTransform
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
    
    ///enter all locations here
    func getLocationType(location:LocationType) -> String {
        switch location {
        case .BootCamp:
            return "eeb38592-4a3c-4d4b-b4c6-38fd68331521"
        case .EugeneKitchen:
            return "vps_kitchen_test"
        case .Polytech:
            return "Polytech"
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
