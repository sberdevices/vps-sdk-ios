//
//  ViewController.swift
//  polytest
//
//  Created by Eugene Smolyakov on 25.09.2020.
//

import ARKit
import VPSNMobile

class ViewController: UIViewController, ARSCNViewDelegate {
    @IBOutlet weak var stope: UIButton!
    @IBOutlet weak var sceneView: ARSCNView!
    
    @IBOutlet weak var statuslbl: UILabel!
    @IBOutlet weak var starte: UIButton!
    @IBOutlet weak var switc: UISwitch!
    var vps: VPSService?
    var firstLocalize = true
    var firstLoading = 0 {
        didSet {
            if firstLoading == 2 {
                downloadView?.removeFromSuperview()
                downloadView = nil
            }
        }
    }
    var oldGraphics: SCNNode = SCNNode()
    var configuration: ARWorldTrackingConfiguration!
    let url = "https://vps.arvr.sberlabs.com/polytech-stage/"
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.scene = SCNScene()
        sceneView.delegate = self
        addloading()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.downloadView?.loading()
            self.downloadView?.addAnimate()
        }
        if let config = VPSBuilder.getDefaultConfiguration() {
            configuration = config
        } else {
            fatalError()
        }
        
        let set = Settings(
                url: url,
                locationID: "Polytech",
            recognizeType: .mobile)
        
        VPSBuilder.initializeVPS(arsession: sceneView.session,
                                 settings: set,
                                 gpsUsage: true,
                                 onlyForceMode: true,
                                 serialLocalizeEnabled: false,
                                 delegate: self) { (serc) in
            self.vps = serc
            self.firstLoading += 1
        } loadingProgress: { (pr) in
            if let prv = self.downloadView {
                prv.downloading()
                prv.progbar.progress = Float(pr)
            } else {
                print("azxsd")
                self.downloadView?.downloading()
            }
        } failure: { (er) in
            print("err",er)
        }
        
        let longgest = UILongPressGestureRecognizer(target: self, action: #selector(longg))
        longgest.minimumPressDuration = 1
        view.addGestureRecognizer(longgest)
        addContent()
    }
    
    func addContent() {
        DispatchQueue.global().async {
            let scene = self.sceneView.scene
            let roomscene = SCNScene(named: "scn.scnassets/polytechcopy.scn")!
            let sten = roomscene.rootNode.childNode(withName: "Mesh534", recursively: true)!
            sten.geometry?.firstMaterial?.isDoubleSided = true
            sten.renderingOrder = -100
            sten.geometry?.firstMaterial!.colorBufferWriteMask = .alpha
            
            let old = SCNScene(named: "Polytech.scn")!
            old.rootNode.childNodes.forEach { (node) in
                scene.rootNode.addChildNode(node)
            }
            self.oldGraphics.name = "oldGraphics"
            scene.rootNode.addChildNode(sten)
            self.sceneView.prepare([scene]) { bol in
                if bol {
                    scene.rootNode.childNodes.forEach({$0.isHidden = true})
                    self.firstLoading += 1
                }
            }
        }
    }
    
    @objc func longg(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            guard var vps = vps else { return  }
            let model = self.sceneView.scene.rootNode.childNode(withName: "Mesh534", recursively: true)!
            let hid = model.geometry!.firstMaterial!.colorBufferWriteMask != .alpha
            let vc = DebugPopVC(docalibrateON: vps.onlyForceMode,
                                autoFocusOn: configuration.isAutoFocusEnabled,
                                showModels: hid,
                                gpsOn: vps.gpsUsage,
                                serialOn: vps.serialLocalizeEnabled)
            vc.serialsw.isEnabled = false
            vc.docalibrsw.isEnabled = false
            self.present(vc, animated: true, completion: nil)
            vc.closeHandler = {
                vc.dismiss(animated: true, completion: nil)
            }
            vc.focusHandler = { (en) in
                self.configuration.isAutoFocusEnabled = en
                self.sceneView.session.run(self.configuration)
            }
            vc.serialHandler = { en in
                vps.serialLocalizeEnabled = en
            }
            vc.modelHandler = {(en) in
                model.geometry?.firstMaterial!.colorBufferWriteMask = en ? .all : .alpha
            }
            vc.gpsHandler = { (en) in
                vps.gpsUsage = en
            }
            vc.docalibHandler = { (en) in
                vps.onlyForceMode = en
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sceneView.session.run(configuration)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    @IBAction func start(_ sender: Any) {
        vps?.start()
        starte.isHidden = true
        stope.isHidden = false
        statuslbl.isHidden = false
    }
    
    @IBAction func stop(_ sender: Any) {
        vps?.stop()
        starte.isHidden = false
        stope.isHidden = true
    }
    
    @IBAction func switched(_ sender: UISwitch) {
        vps = nil
        let set = Settings(
            url: url,
            locationID: "Polytech",
            recognizeType: sender.isOn ? .mobile : .server)
        VPSBuilder.initializeVPS(arsession: sceneView.session,
                                 settings: set,
                                 gpsUsage: true,
                                 onlyForceMode: true,
                                 serialLocalizeEnabled: false,
                                 delegate: self) { (serc) in
            self.vps = serc
            self.downloadView?.removeFromSuperview()
            self.downloadView = nil
        } loadingProgress: { (pr) in
            if let prv = self.downloadView {
                prv.progbar.progress = Float(pr)
            } else {
                self.addloading()
                self.downloadView?.downloading()
            }
        } failure: { (er) in
            print("err",er)
        }
    }
   
    func sessionWasInterrupted(_ session: ARSession) {
        vps?.stop()
        starte.isHidden = false
        stope.isHidden = true
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        vps?.frameUpdated()
    }
    
    var downloadView: DownLaunchAR?
    func addloading() {
        downloadView = DownLaunchAR()
        downloadView?.loading()
        downloadView?.closeHandler = {
            self.downloadView?.removeFromSuperview()
            self.downloadView = nil
        }
        downloadView?.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(downloadView!)
        self.view.addConstraints([
            downloadView!.topAnchor.constraint(equalTo: self.view.topAnchor),
            downloadView!.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            downloadView!.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            downloadView!.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
    }
}

extension ViewController: VPSServiceDelegate {
    func onSerialProgressUpdate(processedImages: Int) {
        
    }
    
    func serialcount(doned: Int) {
        
    }

    func sending() {
        statuslbl.backgroundColor = .cyan
    }

    func error(err: NSError) {
        print("err", err)
        statuslbl.backgroundColor = .red
    }

    func positionVPS(pos: ResponseVPSPhoto) {
        print("delegate", pos)
        if !pos.status {
            statuslbl.backgroundColor = .yellow
        } else {
            statuslbl.backgroundColor = .green
            statuslbl.text = "Succes"
            if firstLocalize {
                firstLocalize = false
                switc.isHidden = false
                sceneView.scene.rootNode.childNodes.forEach { (node) in
                    node.isHidden = false
                }
            }
        }
    }
}
