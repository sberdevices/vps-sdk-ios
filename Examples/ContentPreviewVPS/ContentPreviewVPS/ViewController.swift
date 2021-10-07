import UIKit
import SceneKit
import VPSNMobile

struct CONSTS {
    static let PhNum = 10
}
class ViewController: UIViewController {
    @IBOutlet weak var labell: UILabel!
    @IBOutlet weak var secslider: UISlider!
    
    @IBOutlet weak var switc: UISwitch!
    @IBOutlet weak var sceneView: SCNView!
    
    @IBOutlet weak var activity: UIActivityIndicatorView!
    var player:SCNNode!
    var stens:SCNNode!
    var firstLocalize = true
    var curentindex = 1
    var vps:VPSService?
    let fakears = FakeARS()
    
    var firstLoading = 0 {
        didSet {
            if firstLoading == 2 {
                downloadView?.removeFromSuperview()
                downloadView = nil
                sendPhoto(ind: curentindex)
            }
        }
    }
    
    let url = "https://vps.arvr.sberlabs.com/polytech-pub/"
    let locationID = "Polytech"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.scene = SCNScene()
        addloading()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.downloadView?.loading()
            self.downloadView?.addAnimate()
        }
        labell.text = "1"
        let cameranode = SCNNode()
        cameranode.camera = SCNCamera()
        cameranode.camera?.zFar = 1000
        cameranode.camera?.fieldOfView = 66
        
        sceneView.scene?.rootNode.addChildNode(cameranode)
        player = cameranode
        sceneView.backgroundColor = UIColor.clear
        secslider.addTarget(self, action: #selector(onSliderValChanged(slider:event:)), for: .valueChanged)
        secslider.maximumValue = Float(CONSTS.PhNum)
        let set = Settings(
            url: url,
            locationID: locationID,
            recognizeType: .mobile)
        VPSBuilder.initializeVPS(arsession: fakears.session,
                                 settings: set,
                                 gpsUsage: false,
                                 onlyForceMode: true,
                                 serialLocalizeEnabled: false,
                                 delegate: self) { (serc) in
            self.vps = serc
            self.firstLoading += 1
        } loadingProgress: { (pr) in
            if let prv = self.downloadView {
                self.downloadView?.downloading()
                prv.progbar.progress = Float(pr)
            } else {
                print("azxsd")
                self.downloadView?.downloading()
            }
        } failure: { (er) in
            print("err",er)
        }
        addContent()
    }
    func addContent() {
        DispatchQueue.global().async {
            let scene = self.sceneView.scene!
            let roomscene = SCNScene(named: "polyoccluder2.usdz")!
            let sten = roomscene.rootNode.childNode(withName: "polyoccluder", recursively: true)!
                .childNode(withName: "Geom", recursively: true)!
                .childNode(withName: "polyoccluder_Mesh134_OuterShell5________________1_Group4_Model_011", recursively: true)!
            sten.renderingOrder = -100
            sten.geometry?.firstMaterial?.transparency = 0.5
            self.stens = sten
            scene.rootNode.addChildNode(sten)
            let objectS = SCNScene(named: "DemoRobot.usdz")!
            objectS.rootNode.childNodes.forEach { (node) in
                scene.rootNode.addChildNode(node)
            }
            self.sceneView.prepare([scene]) { bol in
                if bol {
                    scene.rootNode.childNodes.forEach({$0.isHidden = true})
                    self.firstLoading += 1
                }
            }
        }
    }
    
    @objc func onSliderValChanged(slider: UISlider, event: UIEvent) {
        labell.text = "\(Int(slider.value))"
        if let touchEvent = event.allTouches?.first {
            switch touchEvent.phase {
            case .ended:
                print(Int(slider.value))
                sendPhoto(ind: Int(slider.value))
                curentindex = Int(slider.value)
            default:
                break
            }
        }
        
    }
    @IBAction func leftt(_ sender: UIButton) {
        if curentindex > 1 {
            curentindex -= 1
            sendPhoto(ind: curentindex)
            secslider.setValue(Float(curentindex), animated: true)
            labell.text = "\(curentindex)"
        }
    }
    
    @IBAction func righttttt(_ sender: UIButton) {
        if curentindex < CONSTS.PhNum {
            curentindex += 1
            sendPhoto(ind: curentindex)
            secslider.setValue(Float(curentindex), animated: true)
            labell.text = "\(curentindex)"
        }
    }
    @IBAction func servermobile(_ sender: UISwitch) {
        activity.startAnimating()
        
        let set = Settings(
            url: url,
            locationID: locationID,
            recognizeType: sender.isOn ? .mobile : .server)
        VPSBuilder.initializeVPS(arsession: fakears.session,
                                 settings: set,
                                 gpsUsage: false,
                                 onlyForceMode: true,
                                 serialLocalizeEnabled: false,
                                 delegate: self) { (serc) in
            self.vps = serc
            self.downloadView?.removeFromSuperview()
            self.downloadView = nil
            self.sendPhoto(ind: self.curentindex)
        } loadingProgress: { (pr) in
            if let prv = self.downloadView {
                prv.progbar.progress = Float(pr)
            } else {
                self.downloadView?.downloading()
            }
        } failure: { (er) in
            print("err",er)
        }
        labell.text = sender.isOn ? "Mobile" : "Server"
    }
    
    @IBAction func switched(_ sender: UISwitch) {
        if sender.isOn {
            stens.geometry?.firstMaterial!.colorBufferWriteMask = .all
        } else {
            stens.geometry?.firstMaterial!.colorBufferWriteMask = .alpha
        }
    }
    
    func sendPhoto(ind: Int) {
        let image = UIImage(named: "\(ind)")!
        vps?.sendUIImage(image: image)
        activity.startAnimating()
        sceneView.scene?.background.contents = UIImage(named: "\(ind)")!
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
    
    func positionVPS(pos: ResponseVPSPhoto) {
        print(pos)
//        if firstLocalize {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//                self.activity.stopAnimating()
//            }
//        } else {
//            activity.stopAnimating()
//        }
        activity.stopAnimating()
        if pos.status {
            player.position = SCNVector3(pos.posX, pos.posY, pos.posZ)
            player.eulerAngles = SCNVector3(pos.posPitch*Float.pi/180.0,
                                            pos.posYaw*Float.pi/180.0,
                                            pos.posRoll*Float.pi/180.0)
            if firstLocalize {
                self.firstLocalize = false
                switc.isHidden = false
                sceneView.scene?.rootNode.childNodes.forEach({$0.isHidden = false})
            }
        } else {
//            self.activity.stopAnimating()
            let ac = UIAlertController(title: "Error", message: "Localization failed!", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
            ac.addAction(okAction)
            present(ac, animated: true, completion: nil)
        }
    }
    
    func error(err: NSError) {
        self.activity.stopAnimating()
        let ac = UIAlertController(title: "Error", message: "\(err.localizedDescription)", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        ac.addAction(okAction)
        self.present(ac, animated: true, completion: nil)
    }
    
    func sending() {
    }
    
    func downloadProgr(value: Double) {
        DispatchQueue.main.async {
            if let prv = self.downloadView {
                prv.progbar.progress = Float(value)
            } else {
                self.addloading()
                self.downloadView?.downloading()
            }
            if value >= 1.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.downloadView?.removeFromSuperview()
                    self.sendPhoto(ind: self.curentindex)
                }
            }
        }
    }
}
