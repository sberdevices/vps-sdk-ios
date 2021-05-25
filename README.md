# VPS SDK (iOS)
[![CocoaPods Compatible](https://img.shields.io/badge/pod-0.0.4-brightgreen)](https://img.shields.io/badge/pod-0.0.4-brightgreen)  

This SDK allows to determine users position via Visual Positioning System (VPS) API.

## Requirements

- iOS 12.0+
- Xcode 12+
- Swift 5+

## Installation

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate VPS SDK into your Xcode project using CocoaPods, specify it in your `Podfile`:

```
source 'https://github.com/CocoaPods/Specs.git'
source 'https://gitlab.com/labsallday/vps-client-apps-public/labpodspecs'
target 'YOUR PROJECT NAME HERE' do
  use_frameworks!
pod 'VPSNMobile'
end
```
And run `pod install` from project directory

### User permisions

Add flags to access user's location and camera into `info.plist`. TemporaryAuth is required for devices running iOS 14+.

```xml
<key>NSCameraUsageDescription</key>
    <string></string>
<key>NSLocationWhenInUseUsageDescription</key>
    <string></string>
<key>NSLocationTemporaryUsageDescriptionDictionary</key>
    <dict>
        <key>TemporaryAuth</key>
        <string></string>
    </dict>
```
## Usage

* You must define a `ARSCNViewDelegate` delegate and call the method `vps?.frameUpdated()` each frame update
* Assign the default configuration using a method `getDefaultConfiguration()` that will return nil if the device is not supported.
* You can use the delegate method `sessionWasInterrupted` to stop the VPS when the application moves foreground and start it again in `sessionInterruptionEnded`

```swift
import VPSNMobile
import UIKit
import ARKit

class Example:UIViewController, ARSCNViewDelegate {
    var arview: ARSCNView!
    var configuration: ARWorldTrackingConfiguration!
    var vps: VPSService?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        arview.scene = SCNScene()
        arview.delegate = self
        if let config = VPSBuilder.getDefaultConfiguration() {
            configuration = config
        } else {
            fatalError()
        }
        
        let set = Settings(
            url: "https://...",
            locationID: "ID",
            recognizeType: .server)
            
        VPSBuilder.initializeVPS(arsession: arview.session,
                                 settings: set,
                                 gpsUsage: false,
                                 onlyForceMode: true,
                                 serialLocalizeEnabled: false,
                                 delegate: nil) { (vps) in
            self.vps = vps
        }
        vps?.Start()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        arview.session.run(configuration)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        vps?.frameUpdated()
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        vps?.Stop()
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        vps?.Start()
    }
}
```

### Mobile VPS

To enable the mobile VPS mode, you need to select it in the settings `recognizeType: .mobile`. In this case, the neural network will be downloaded to the device, the progress of which can be tracked in the `loadingProgress` handler, if the model was not downloaded, or could not be initialized, the `failure` handler will report this.
```swift
VPSBuilder.initializeVPS(arsession: arview.session,
                         settings: set,
                         gpsUsage: false,
                         onlyForceMode: true,
                         serialLocalizeEnabled: false,
                         delegate: self) { (serc) in
    self.vps = serc
} loadingProgress: { (pr) in
    print("value",pr)
} failure: { (er) in
    print("err",er)
}
```

### RealityKit

Using realitykit is similar to using scenekit. Instead of using `func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval)` you need to use `func session(_ session: ARSession, didUpdate frame: ARFrame)` using ARSessionDelegate for call call the method `vps?.frameUpdated()` each frame

```swift
func session(_ session: ARSession, didUpdate frame: ARFrame) {
    
}
```

### SwiftUI
For better use in swiftui, you can use the MVVM architecture. Create a reference to the ViewModel class in the VIEW structure. In the ViewModel, place the vpsservice and subscribe to the VPSServiceDelegate protocol. Now you can manage the VPS Service via the ViewModel. But we must not forget about the frame update method. Since we are using ARSCNView, and it is not displayed automatically in the VIEW, we need to create a new VIEW structure under the UIViewRepresentable protocol. Inside, create a SCNCoordinator class that inherits NSObject and ARSCNViewDelegate. Now you can call the `frameUpdated()` method inside SCNCoordinator in the `func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval)`  by accessing ViewModel - > vpsservice
```swift
struct ContentView: View {
    @State var vpsStarted = false
    let arv = SampleVPS()
    var body: some View {
        VStack {
            arv
                .background(Color.red)
                .cornerRadius(20)
                .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            Button(vpsStarted ? "stop" : "start") {
                vpsStarted ? arv.vm.vps?.Stop() : arv.vm.vps?.Start()
                
                withAnimation(.linear) {
                    vpsStarted.toggle()
                }
            }
            .frame(width: 300, height: 50, alignment: .center)
            .background(vpsStarted ? Color.red : Color.green)
            .cornerRadius(20)
            .padding()
        }
    }
}

class ViewModel: VPSServiceDelegate {
    var vps:VPSService?

    init(sesion:ARSession) {
        
            let set = Settings(
                url: "",
                locationID: "",
                recognizeType: .server)
        VPSBuilder.initializeVPS(arsession: sesion,
                                 settings: set,
                                 gpsUsage: false,
                                 onlyForceMode: true,
                                 serialLocalizeEnabled: false,
                                 delegate: self) { (vps) in
            self.vps = vps
        } loadingProgress: { (pr) in
        } failure: { (er) in
            print("err",er)
        }

    }
    
    func serialcount(doned: Int) {
        
    }
    
    func positionVPS(pos: ResponseVPSPhoto) {
        print("pos",pos)
    }
    
    func error(err: NSError) {
        
    }
    
    func sending() {
        
    }
}
struct SampleVPS: UIViewRepresentable {
    var vm: ViewModel
    let sceneView = ARSCNView()
    
    init() {
        let config = VPSBuilder.getDefaultConfiguration()!
        config.isAutoFocusEnabled = true
        sceneView.session.run(config)
        vm = ViewModel(sesion: sceneView.session)
    }
    
    
    func makeUIView(context: Context) -> ARSCNView {
        sceneView.backgroundColor = .green
        sceneView.scene = SCNScene(named: "polytechcopy.scn")!
        sceneView.delegate = context.coordinator
        
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
    }
    
    func makeCoordinator() -> SCNCoordinator {
        SCNCoordinator(self)
    }
    
    class SCNCoordinator: NSObject, ARSCNViewDelegate {
        
        var control: SampleVPS
        
        init(_ control: SampleVPS) {
            self.control = control
            print("Control is ready!")
        }
        
        func renderer(_ renderer: SCNSceneRenderer,
                      updateAtTime time: TimeInterval) {
            control.vm.vps?.frameUpdated()
        }
    }
}

struct ARKitView: UIViewRepresentable {
    let sceneView = ARSCNView()
    var vps:VPSService!
    
    class SCNCoordinator: NSObject, ARSCNViewDelegate, VPSServiceDelegate, ARSessionDelegate {
        func serialcount(doned: Int) {
            
        }
        
        func positionVPS(pos: ResponseVPSPhoto) {
            print(pos)
        }
        
        func error(err: NSError) {
            print(err)
        }
        
        func sending() {
            
        }
        
        var control: ARKitView
        
        init(_ control: ARKitView) {
            self.control = control
            super.init()
            let set = Settings(
                url: "https://api.polytech.vps.arvr.sberlabs.com/",
                locationID: "Polytech",
                recognizeType: .server)
            VPSBuilder.initializeVPS(arsession: control.sceneView.session,
                                     settings: set,
                                     gpsUsage: false,
                                     onlyForceMode: true,
                                     serialLocalizeEnabled: false,
                                     delegate: self) { (serc) in
                self.control.vps = serc
                self.control.vps.Start()
            } loadingProgress: { (pr) in
            } failure: { (er) in
                print("err",er)
            }
        }
        
        func renderer(_ renderer: SCNSceneRenderer,
                      updateAtTime time: TimeInterval) {
        }
        
    }
    func makeUIView(context: Context) -> ARSCNView {
        sceneView.backgroundColor = .green
        sceneView.scene = SCNScene(named: "polytechcopy.scn")!
        sceneView.delegate = context.coordinator
        
        let config = VPSBuilder.getDefaultConfiguration()!
        config.isAutoFocusEnabled = true
        sceneView.session.run(config)
        return sceneView
    }
    func updateUIView(_ uiView: ARSCNView, context: Context) {
    }
    func makeCoordinator() -> SCNCoordinator {
        SCNCoordinator(self)
    }
}
```
