//
//  Function.swift
//  VPSNMobile
//
//  Created by Eugene Smolyakov on 20.11.2020.
//

import SceneKit

func modelPath(name:String, folder: String) -> URL? {
    guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first,
    let writePath = NSURL(fileURLWithPath: path).appendingPathComponent(folder) else { return nil }
    try? FileManager.default.createDirectory(atPath: writePath.path, withIntermediateDirectories: true)
    let file = writePath.appendingPathComponent(name)
    if (FileManager.default.fileExists(atPath: file.path)){
        return file
    } else {
        return nil
    }
}

func saveModel(from:URL, name:String, folder: String) -> URL? {
    guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first,
    let writePath = NSURL(fileURLWithPath: path).appendingPathComponent(folder) else { return nil }
    do {
        try FileManager.default.createDirectory(atPath: writePath.path, withIntermediateDirectories: true)
    } catch let error {
        print("err1",error)
    }
    let file = writePath.appendingPathComponent(name)
    if (FileManager.default.fileExists(atPath: file.path)){
         try! FileManager.default.removeItem(atPath: file.path)
    }
    print("from",from.path)
    print("path2",file.path)
    do {
        try FileManager.default.moveItem(at: from, to: file)
        return file
    } catch  let error {
        print("err",error)
        return nil
    }
}

func getAngleFrom(eulere: SCNVector3) -> Float {
    let node = SCNNode()
    node.eulerAngles = eulere
    return getAngleFrom(transform: node.transform)
}

func getAngleFrom(transform: SCNMatrix4) -> Float {
    let orientation = SCNVector3(transform.m31, transform.m32, transform.m33)
    return atan2f(orientation.x, orientation.z)
}

func getAngleFrom(transform: simd_float4x4) -> Float {
    let orientation = SIMD3<Float>(transform[2][0],transform[2][1],transform[2][2])
    return atan2f(orientation.x, orientation.z)
}

func getTransformPosition(from transform: simd_float4x4) -> SIMD3<Float> {
    return SIMD3<Float>(transform[3][0],
                        transform[3][1],
                        transform[3][2])
}

func getWorldTransform(childPos:SIMD3<Float> = .zero,
                       parentPos:SIMD3<Float> = .zero,
                       parentEuler:SIMD3<Float> = .zero) -> simd_float4x4 {
    let child = SCNNode()
    child.position = SCNVector3(-childPos)
    let parent = SCNNode()
    parent.addChildNode(child)
    parent.position = SCNVector3(parentPos)
    parent.eulerAngles = SCNVector3(parentEuler)
    return child.simdWorldTransform
}

public func clamped<T>(_ value: T, minValue: T, maxValue: T) -> T where T : Comparable {
    return min(max(value, minValue), maxValue)
}

func makeErr(with cwd:codeWithDescr) -> NSError {
    return NSError(domain: "VPS",
                   code: cwd.code,
                   userInfo: [NSLocalizedDescriptionKey: cwd.descr])
}
