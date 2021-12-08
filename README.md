![logo](./img/logo.png)

# VPS SDK (iOS)
[![CocoaPods Compatible](https://img.shields.io/badge/pod-0.2.0-brightgreen)](https://img.shields.io/badge/pod-0.1.2-brightgreen)  

This is **Visual Positioning System** SDK for Native iOS apps. Main features are:
- High-precision global user position localization for your AR apps
- Easy to use public API
- Integration in SceneKit and RealityKit
- Works both for UIKit and SwiftUI apps

For more information visit [our page on SmartMarket](https://developers.sber.ru/portal/tools/visual-positioning-system-sdk). If you want access to other VPS locations or want to scan your own proprerty, please contact us at <arvrlab@sberbank.ru>.

## Requirements

- iOS 12.0+
- Xcode 12+
- Swift 5+
- ARKit supported device

## Installation

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate VPS SDK into your Xcode project using CocoaPods, specify it in your `Podfile`:

```
source 'https://github.com/CocoaPods/Specs.git'
target 'YOUR PROJECT NAME HERE' do
  use_frameworks!
pod 'VPSNMobile'
end
```
Run `pod install` from the project directory to create a new workspace file.

### From sources

You can also build VPS framework from this repository. 

Clone this repository and run `pod install` from the project directory. A new workspace file will be created. Now you can build VPS framework and link it to your apps.

## Examples

There are several example apps included in this repository:
- [ContentPreviewVPS](/Examples/ContentPreviewVPS) - test VPS service from simulator without visiting the real location
- [ExampleAppVPS](/Examples/ExampleAppVPS) - integration of VPS service in a real end-user app

To install an example project, clone this repository. Run `pod install` from the selected example directory to create a new workspace file.

## Usage

### User permissions

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

### UIKit

* You must define a `ARSCNViewDelegate` delegate and call the method `vps?.frameUpdated()` each frame
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
        vps?.start()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        arview.session.run(configuration)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        vps?.frameUpdated()
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        vps?.stop()
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        vps?.start()
    }
}
```

### Mobile VPS

To enable the mobile VPS mode, you need to select it in the settings `recognizeType: .mobile`. In this case, the neural network will be downloaded to the device, the progress of which can be tracked in the `loadingProgress` handler. If the model failed to download or could not be initialized, the `failure` handler will report this.
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

Using RealityKit is similar to using SceneKit. Instead of using `func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval)` you need to use `func session(_ session: ARSession, didUpdate frame: ARFrame)` using ARSessionDelegate for call call the method `vps?.frameUpdated()` each frame.

```swift
func session(_ session: ARSession, didUpdate frame: ARFrame) {
    
}
```

### SwiftUI
For better use in SwiftUI, you should use the MVVM architecture. Here is a quick example:
```swift
struct ContentView: View {
    @StateObject var vm = ViewModel()
    @State var vpsStarted = false
    var body: some View {
    VStack {
        ARView(vm: vm)
            .background(Color.gray)
            .cornerRadius(20)
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
        Button(vpsStarted ? "stop" : "start") {
            vpsStarted ? vm.vps?.Stop() : vm.vps?.Start()
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

class ViewModel:NSObject, ObservableObject, ARSCNViewDelegate, VPSServiceDelegate {
    
    var vps: VPSService?
    func initVPS(session:ARSession) {
        let set = Settings(
            url: "...",
            locationID: "...",
            recognizeType: .server)
        VPSBuilder.initializeVPS(arsession: session,
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
        print("POS",pos)
    }
    
    func error(err: NSError) {
        
    }
    
    func sending() {
        
    }
}

struct ARView: UIViewRepresentable {
    
    @ObservedObject var vm: ViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.scene = SCNScene(named: "polytechcopy.scn")!
        sceneView.autoenablesDefaultLighting = true
        sceneView.delegate = vm
        vm.initVPS(session: sceneView.session)
        let config = VPSBuilder.getDefaultConfiguration()!
        config.isAutoFocusEnabled = true
        sceneView.session.run(config)
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
    }
    
    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ()) {
        uiView.delegate = nil
    }
}
```
