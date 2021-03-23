//
//  Entities.swift
//  VPSService
//
//  Created by Eugene Smolyakov on 04.09.2020.
//  Copyright © 2020 ARVRLAB. All rights reserved.
//

import UIKit

struct UploadVPSPhoto {
    var job_id: String
    var locationType: String
    var locationID: String
    var locationClientCoordSystem: String
    var locPosX: Float
    var locPosY: Float
    var locPosZ: Float
    var locPosRoll: Float
    var locPosPitch: Float
    var locPosYaw: Float
    var imageTransfOrientation: Int
    var imageTransfMirrorX: Bool
    var imageTransfMirrorY: Bool
    var instrinsicsFX: Float
    var instrinsicsFY: Float
    var instrinsicsCX: Float
    var instrinsicsCY: Float
    var image: UIImage?
    var gps:GPS?
    var compas:Compas?
    var forceLocalization:Bool
}

struct GPS {
    var lat:Double
    var long:Double
    var alt:Double
    var acc:Double
    var timestamp:Double
}

struct Compas {
    var heading:Double
    var acc:Double
    var timestamp:Double
}

struct Media {
    let key: String
    let filename: String
    let data: Data
    let mimeType: String
    
    init(withImage image: UIImage, forKey key: String) {
        self.key = key
        self.mimeType = "image/jpeg"
        self.filename = "\(NSUUID().uuidString).jpg"
        self.data = image.jpegData(compressionQuality: 1) ?? Data()
    }
    
}

typealias codeWithDescr = (code:Int, descr:String)
struct Errors {
    static let e1 = codeWithDescr(1,"Failed to initialize tf model")
    static let e2 = codeWithDescr(2, "Cant save tf model")
    static let e3 = codeWithDescr(3, "Cant get predict")
    static let e4 = codeWithDescr(3, "cant get renderer uiimage")
    static let e5 = codeWithDescr(4, "cant init HairRenderer")
}
