//
//  VPSServiceExtension.swift
//  secFramework
//
//  Created by Eugene Smolyakov on 04.09.2020.
//  Copyright © 2020 ES. All rights reserved.
//

import ARKit

extension VPSService {
    func setupScene(arsession: ARSession,
                    url: String,
                    locationID:String,
                    onlyForce:Bool,
                    recognizeType:RecognizeType){
        vps = VPS(arsession: arsession,
                  url: url,
                  locationID: locationID,
                  onlyForce: onlyForce,
                  recognizeType:recognizeType)
        vps?.delegate = self
    }
}

extension VPSService: VPSDelegate {
    func sending() {
        delegate?.sending()
    }
    
    func error(err: NSError) {
        delegate?.error(err: err)
    }
    
    func positionVPS(pos: ResponseVPSPhoto) {
        delegate?.positionVPS(pos: pos)
    }
}
