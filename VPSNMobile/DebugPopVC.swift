//
//  DebugPopVC.swift
//  VPSNMobile
//
//  Created by Eugene Smolyakov on 04.03.2021.
//

import UIKit

public class DebugPopVC: UIViewController {
    var mainStack: UIStackView!
    
    let docalibrlbl = UILabel()
    let docalibrsw = UISwitch()
    let focuslbl = UILabel()
    let focussw = UISwitch()
    let showmodellbl = UILabel()
    let showmodelsw = UISwitch()
    let gpslbl = UILabel()
    let gpssw = UISwitch()
    
    let closebtn = UIButton(type: .system)
    
    
    public required init(docalibrateON:Bool,
                         autoFocusOn:Bool,
                         showModels:Bool,
                         gpsOn:Bool) {
        docalibrlbl.text = docalibrateON ? "ForceLocal ON" : "ForceLocal OFF"
        docalibrsw.isOn = docalibrateON
        focuslbl.text = autoFocusOn  ? "Focus ON" : "Focus OFF"
        focussw.isOn = autoFocusOn
        showmodellbl.text = showModels ? "Model ON" : "Model OFF"
        showmodelsw.isOn = showModels
        gpslbl.text = gpsOn  ? "GPS ON" : "GPS OFF"
        gpssw.isOn = gpsOn
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overCurrentContext
        self.modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        docalibrsw.addTarget(self, action: #selector(docalibract), for: .valueChanged)
        focussw.addTarget(self, action: #selector(focusact), for: .valueChanged)
        showmodelsw.addTarget(self, action: #selector(modelact), for: .valueChanged)
        gpssw.addTarget(self, action: #selector(gpsact), for: .valueChanged)
        
        let docalibrStack = stacked(vs: [docalibrsw,docalibrlbl])
        let focusStack = stacked(vs: [focussw,focuslbl])
        let modelsStack = stacked(vs: [showmodelsw,showmodellbl])
        let gpsStack = stacked(vs: [gpssw,gpslbl])
        
        mainStack = UIStackView(arrangedSubviews: [docalibrStack,focusStack,modelsStack,gpsStack])
        mainStack.axis = .vertical
        mainStack.distribution = .fillEqually
        if #available(iOS 13.0, *) {
            mainStack.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.5)
        } else {
            mainStack.backgroundColor = UIColor.white.withAlphaComponent(0.5)
            // Fallback on earlier versions
        }
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.layer.cornerRadius = 15
        mainStack.layer.masksToBounds = true
        mainStack.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        mainStack.isLayoutMarginsRelativeArrangement = true
        
        self.view.addSubview(mainStack)
        self.view.addConstraints([
            mainStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            mainStack.heightAnchor.constraint(equalToConstant: 200),
            mainStack.widthAnchor.constraint(equalToConstant: 200)
        ])
        closebtn.setTitle("close", for: .normal)
        closebtn.addTarget(self, action: #selector(closevc), for: .touchUpInside)
        if #available(iOS 13.0, *) {
            closebtn.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.5)
        } else {
            closebtn.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        }
        closebtn.layer.cornerRadius = 15
        closebtn.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(closebtn)
        self.view.addConstraints([
            closebtn.bottomAnchor.constraint(equalTo: mainStack.topAnchor, constant: -20),
            closebtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closebtn.heightAnchor.constraint(equalToConstant: 40),
            closebtn.widthAnchor.constraint(equalToConstant: 60)
        ])
    }

    @objc func closevc(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    public var docalibHandler:((Bool) -> ())?
    @objc func docalibract(_ sender: UISwitch) {
        docalibHandler?(sender.isOn)
        docalibrlbl.text = sender.isOn ? "Docalibrate ON" : "Docalibrate OFF"
    }

    public var focusHandler:((Bool) -> ())?
    @objc func focusact(_ sender: UISwitch) {
        focusHandler?(sender.isOn)
        focuslbl.text = sender.isOn ? "Focus ON" : "Focus OFF"
    }
    
    public var modelHandler:((Bool) -> ())?
    @objc func modelact(_ sender: UISwitch) {
        modelHandler?(sender.isOn)
        showmodellbl.text = sender.isOn ? "Model ON" : "Model OFF"
    }
    
    public var gpsHandler:((Bool) -> ())?
    @objc func gpsact(_ sender: UISwitch) {
        gpsHandler?(sender.isOn)
        gpslbl.text = sender.isOn ? "GPS ON" : "GPS OFF"
    }
    
    func stacked(vs: [UIView]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: vs)
        stack.alignment = .center
        stack.spacing = 10
        return stack
    }
}