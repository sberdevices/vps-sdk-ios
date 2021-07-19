//
//  Entities.swift
//  VPSService
//
//  Created by Eugene Smolyakov on 04.09.2020.
//  Copyright © 2020 ARVRLAB. All rights reserved.
//

import UIKit
import simd

typealias MYFloat16 = UInt16

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
    var features:NeuroData?
    var gps:GPS?
    var compas:Compas?
    var forceLocalization:Bool
    var photoTransform:simd_float4x4?
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

struct NeuroData {
    let global_descriptor:[MYFloat16]
    let keyPoints:[MYFloat16]
    let scores:[MYFloat16]
    let desc:[MYFloat16]
    let filename: String
    let mimeType: String
    
    
    init(global_descriptor: [MYFloat16],
         keyPoints: [MYFloat16],
         scores: [MYFloat16],
         desc: [MYFloat16]) {
        self.global_descriptor = global_descriptor
        self.keyPoints = keyPoints
        self.scores = scores
        self.desc = desc
        self.mimeType = "image/jpeg"
        self.filename = "data.embd"
    }
    
    func getData() -> Data {
        var filedata = Data()
        var version:UInt8 = UInt8(1)
        let versionData = Data(bytes: &version,
                               count: MemoryLayout.size(ofValue: version))
        filedata.append(versionData)
        var ident:UInt8 = UInt8(0)
        let identData = Data(bytes: &ident,
                             count: MemoryLayout.size(ofValue: ident))
        filedata.append(identData)
        for value in [keyPoints,scores,desc,global_descriptor] {
            let data = Data(copyingBufferOf: value)
            var count = UInt32(data.count).bigEndian
            let countData = Data(bytes: &count,
                                 count: MemoryLayout.size(ofValue: count))
            filedata.append(countData)
            filedata.append(data)
        }
        return filedata

    }
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
