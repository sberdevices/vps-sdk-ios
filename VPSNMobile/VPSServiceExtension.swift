//
//  VPSServiceExtension.swift
//  secFramework
//
//  Created by Eugene Smolyakov on 04.09.2020.
//  Copyright © 2020 ES. All rights reserved.
//

import ARKit

extension VPSService {
    func setupScene(arsession: ARSession, location:LocationType){
        vps = VPS(arsession: arsession, location: location)
        vps?.delegate = self
    }
}

extension VPSService: VPSDelegate {
    func error(err: NSError) {
        delegate?.error(err: err)
    }
    
    func positionVPS(pos: ResponseVPSPhoto) {
        delegate?.positionVPS(pos: pos)
    }
}
