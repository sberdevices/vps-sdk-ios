//
//  Entities.swift
//  VPSService
//
//  Created by Eugene Smolyakov on 04.09.2020.
//  Copyright © 2020 ARVRLAB. All rights reserved.
//

import UIKit
import simd

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
    let coreml:[Float32]
    let keyPoints:[Float32]
    let scores:[Float32]
    let desc:[Float32]
    let filename: String
    let mimeType: String
    
    
    init(coreml: [Float32], keyPoints: [Float32], scores: [Float32], desc: [Float32]) {
        self.coreml = coreml
        self.keyPoints = keyPoints
        self.scores = scores
        self.desc = desc
        self.mimeType = "image/jpeg"
        self.filename = "data.embd"
    }
    
    func getData() -> Data {
        var filedata = Data()
        var version:UInt8 = UInt8(0)
        let versionData = Data(bytes: &version,
                             count: MemoryLayout.size(ofValue: version))
        filedata.append(versionData)
        var ident:UInt8 = UInt8(0)
        let identData = Data(bytes: &ident,
                             count: MemoryLayout.size(ofValue: ident))
        filedata.append(identData)
        for value in [keyPoints,scores,desc,coreml] {
            let data: Data = value.withUnsafeBufferPointer { pointer in
                return Data(buffer: pointer)
            }
            let base64String = data.base64EncodedString()
            let bstrdata = base64String.data(using: .utf8) ?? Data()
            var count = UInt32(bstrdata.count).bigEndian
            let countData = Data(bytes: &count,
                                 count: MemoryLayout.size(ofValue: count))
            filedata.append(countData)
            filedata.append(bstrdata)
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
