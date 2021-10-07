import UIKit

class DownLaunchAR: UIView {
    @IBOutlet weak var progbar: UIProgressView!
    @IBOutlet weak var progtext: UILabel!
    
    @IBOutlet weak var descrlbl: UILabel!
    @IBOutlet weak var limage: UIImageView!
    
    @IBOutlet weak var closebutton: UIButton!
    var closeHandler:(() -> ())?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
        
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    func commonInit() {
        guard let nibView = loadFromNib() else {
            print("cant loadfromnib")
            return
        }
        self.addSubview(nibView)
        nibView.frame = bounds
        nibView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        progbar.layer.borderWidth = 3
        closebutton.isHidden = true
    }
    
    func addAnimate() {
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.fromValue = 0.0
        rotationAnimation.toValue = 1
        rotationAnimation.duration = 0.5
        rotationAnimation.repeatCount = .infinity
        limage.layer.add(rotationAnimation, forKey: nil)
    }
    
    func downloading() {
        limage.isHidden = true
        progtext.isHidden = false
        progbar.isHidden = false
        descrlbl.text = "Downloading..."
    }
    
    func loading() {
        limage.isHidden = false
        progtext.isHidden = true
        progbar.isHidden = true
        descrlbl.text = "Loading 3d content..."
    }
    
    @IBAction func close(_ sender: Any) {
        closeHandler?()
    }
    
}

extension UIView {
    func loadFromNib<T: UIView>() -> T? {
        guard let nibView = Bundle(for: type(of: self)).loadNibNamed(String(describing: type(of: self)), owner: self, options: nil)?.first as? T else {
            return nil
        }
        return nibView
    }
}
