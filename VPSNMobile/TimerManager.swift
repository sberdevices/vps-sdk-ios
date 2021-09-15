

import Foundation

protocol TimerManagerDelegate: AnyObject {
    func timerFired()
}

final class TimerManager {
    weak var delegate: TimerManagerDelegate? = nil
    private var timer: Timer?
    var delayTime: TimeInterval = 0
    
    @objc private func updateTimer() {
        delegate?.timerFired()
    }

    func startTimer(timeInterval: TimeInterval,
                    delegate: TimerManagerDelegate,
                    fired:Bool = false) {
        // dont start new timer, when one created
        if timer != nil { return }
        self.delegate = delegate
        let date = Date().addingTimeInterval(fired ? 0 : delayTime)
        let timer = Timer(fireAt: date,
                          interval: timeInterval,
                          target: self,
                          selector: #selector(updateTimer),
                          userInfo: nil,
                          repeats: true)
        RunLoop.current.add(timer, forMode: .common)
        timer.tolerance = 0.1
        self.timer = timer
    }
    
    func invalidateTimer() {
        self.timer?.invalidate()
        self.timer = nil
        self.delegate = nil
    }
    
    func recreate(timeInterval: TimeInterval,
                  delegate: TimerManagerDelegate,
                  fired: Bool = false) {
        if timer == nil { return }
        invalidateTimer()
        startTimer(timeInterval: timeInterval,
                   delegate: delegate,
                   fired: fired)
    }
}
