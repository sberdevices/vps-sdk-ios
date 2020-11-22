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
    func uploadNeuroPhoto(photo: UploadVPSPhoto,
                        coreml:[Float32],
                        keyPoints:[Float32],
                        scores:[Float32],
                        desc:[Float32],
                        success: ((ResponseVPSPhoto) -> Void)?,
                        failure: ((NSError) -> Void)?)
    func downloadNeuroModel(url: ((URL) -> Void)?,
                            failure: ((NSError) -> Void)?)
    
}

extension Network:NetVPSService {
    func downloadNeuroModel(url: ((URL) -> Void)?,
                            failure: ((NSError) -> Void)?) {
        downloadNeuro { (path) in
            url?(path)
        } failure: { (err) in
            failure?(err)
        }
    }
    
    func uploadPanPhoto(photo: UploadVPSPhoto,
                        success: ((ResponseVPSPhoto) -> Void)?,
                        failure: ((NSError) -> Void)?) {
        uploadPhoto(photo: photo, success: { (resp) in
            success?(resp)
        }) { (err) in
            failure?(err)
        }
    }
    func uploadNeuroPhoto(photo: UploadVPSPhoto,
                          coreml:[Float32],
                          keyPoints:[Float32],
                          scores:[Float32],
                          desc:[Float32],
                          success: ((ResponseVPSPhoto) -> Void)?,
                          failure: ((NSError) -> Void)?) {
        uploadNeuro(photo: photo,
            coreml:coreml,
            keyPoints:keyPoints,
            scores:scores,
            desc:desc, success: { (resp) in
                success?(resp)
            }) { (err) in
            failure?(err)
        }
    }
}
