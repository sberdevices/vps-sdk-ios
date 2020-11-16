//
//  Network+getPosition.swift
//  VPSService
//
//  Created by Eugene Smolyakov on 07.09.2020.
//  Copyright © 2020 ARVRLAB. All rights reserved.
//

import Foundation
protocol NetVPSService {
    func uploadPanPhoto(photo: UploadVPSPhoto,
                        success: ((ResponseVPSPhoto) -> Void)?,
                        failure: ((NSError) -> Void)?)
}

extension Network:NetVPSService {
    func uploadPanPhoto(photo: UploadVPSPhoto,
                        success: ((ResponseVPSPhoto) -> Void)?,
                        failure: ((NSError) -> Void)?) {
        get(photo: photo, success: { (resp) in
            success?(resp)
        }) { (err) in
            failure?(err)
        }
    }
}
