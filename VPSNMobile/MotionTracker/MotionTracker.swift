

import Foundation
import CoreMotion

final class MotionTracker {
    private lazy var motionManager: CMMotionManager = {
        let m = CMMotionManager()
        m.deviceMotionUpdateInterval = 1.0 / 90.0
        return m
    } ()
    
    weak var delegate: MotionTrackerServiceListener? = nil
    let queue = OperationQueue()
}

// MARK: - MotionTrackerService
extension MotionTracker: MotionTrackerService {
    func getMotion() -> CMDeviceMotion? {
        return motionManager.deviceMotion
    }
    
    func isAvailable() -> Bool {
        return motionManager.isDeviceMotionAvailable
    }
    
    @discardableResult
    func startTrackingFor(delegate: MotionTrackerServiceListener) -> Error? {
        if !isAvailable() {
            let e = NSError(domain: Const.domain,
                            code: -1,
                            userInfo:
                [
                    NSLocalizedDescriptionKey:
                        "Motion Tracking is not available on your device!".localized
                ])
            return e
        }
        self.delegate = delegate
        queue.qualityOfService = .userInteractive
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] (motion, err) in
            guard let `self` = self else { return }
            self.delegate?.changed(motion: motion, error: err)
        }
        return nil
    }

    func stopTrackingFor() {
        delegate = nil
        motionManager.stopDeviceMotionUpdates()
    }
}
