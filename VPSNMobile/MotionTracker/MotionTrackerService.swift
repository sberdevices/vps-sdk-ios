
import Foundation
import CoreMotion

protocol MotionTrackerServiceListener: AnyObject {
    func changed(motion: CMDeviceMotion?, error: Error?)
}

protocol MotionTrackerService {
    func isAvailable() -> Bool
    @discardableResult
    func startTrackingFor(delegate: MotionTrackerServiceListener) -> Error?
    func stopTrackingFor()
    func getMotion() -> CMDeviceMotion?
}
