//
//  TimerManager.swift
//  VPSNMobile
//
//  Created by Eugene Smolyakov on 23.03.2021.
//

import Foundation

protocol TimerManagerDelegate:class {
    func timerFired()
}

final class TimerManager {
    weak var delegate: TimerManagerDelegate? = nil
    private var timer:Timer?
    
    @objc func updateTimer() {
        delegate?.timerFired()
    }

    func startTimer(timeInterval:TimeInterval, delegate:TimerManagerDelegate) {
        if timer == nil {
            invalidateTimer()
        }
        self.delegate = delegate
        let timer = Timer(timeInterval: timeInterval,
                          target: self,
                          selector: #selector(updateTimer),
                          userInfo: nil,
                          repeats: true)
        RunLoop.current.add(timer, forMode: .common)
        timer.tolerance = 0.1
        self.timer = timer
        self.timer?.fire()
    }
    
    func invalidateTimer() {
        self.timer?.invalidate()
        self.timer = nil
        self.delegate = nil
    }
}