# VPSNMobile

Our SDK, which allows you to determine the position of the camera from the photo via api
**Current version '0.0.2'**

## Requirements

- iOS 12.0+
- Xcode 12+
- Swift 5+

## Installation

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate Alamofire into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'VPSNMobile'
```
And run `pod install` from project directory

## Usage

```swift
import VPSNMobile

class Example {
    var arview: ARSCNView!
    
    var vps = VPSService(arsession: arview.session,
                        url: "http://...",
                        locationID: "ID",
                        onlyForce: true,
                        recognizeType: .server)
                        
    func run() {
        vps.Start()
    }
}
```
**Attention**

* You must define a session delegate or a scene delegate and call the method

```swift
func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    vps.frameUpdated()
}
```
* You must set the correct session configuration

```swift
let configuration = ARWorldTrackingConfiguration()
configuration.isAutoFocusEnabled = false
for format in ARWorldTrackingConfiguration.supportedVideoFormats {
    if format.imageResolution == CGSize(width: 1920, height: 1080) {
        configuration.videoFormat = format
        break
    }
}
arview.session.run(configuration)
```