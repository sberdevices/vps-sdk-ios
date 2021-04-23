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


