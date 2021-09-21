

import SceneKit

func modelPath(name: String, folder: String) -> URL? {
    guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first,
    let writePath = NSURL(fileURLWithPath: path).appendingPathComponent(folder) else { return nil }
    try? FileManager.default.createDirectory(atPath: writePath.path, withIntermediateDirectories: true)
    let file = writePath.appendingPathComponent(name)
    if (FileManager.default.fileExists(atPath: file.path)) {
        return file
    } else {
        return nil
    }
}

func saveModel(from: URL, name:String, folder: String) -> URL? {
    guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first,
    let writePath = NSURL(fileURLWithPath: path).appendingPathComponent(folder) else { return nil }
    do {
        try FileManager.default.createDirectory(atPath: writePath.path, withIntermediateDirectories: true)
    } catch let error {
        print("err1", error)
    }
    let file = writePath.appendingPathComponent(name)
    if (FileManager.default.fileExists(atPath: file.path)) {
         try? FileManager.default.removeItem(atPath: file.path)
    }
//    print("from",from.path)
//    print("path2",file.path)
    do {
        try FileManager.default.moveItem(at: from, to: file)
        return file
    } catch  let error {
        print("err", error)
        return nil
    }
}

public func getEulereFrom(transform: simd_float4x4) -> SIMD3<Float> {
    let node = SCNNode()
    node.simdTransform = transform
    return SIMD3<Float>(node.eulerAngles)
}

public func getTransformFrom(eulere: SIMD3<Float>, position: SIMD3<Float>) -> simd_float4x4 {
    let node = SCNNode()
    node.position = SCNVector3(position)
    node.eulerAngles = SCNVector3(eulere)
    return node.simdTransform
}

public func getTransformFrom(eulere: SIMD3<Float>) -> simd_float4x4 {
    let node = SCNNode()
    node.eulerAngles = SCNVector3(eulere)
    return node.simdTransform
}

public func getAngleFrom(eulere: SCNVector3) -> Float {
    let node = SCNNode()
    node.eulerAngles = eulere
    return getAngleFrom(transform: node.simdTransform)
}

func getAngleFrom(eulere: SIMD3<Double>) -> Double {
    return Double(getAngleFrom(eulere: SCNVector3(Float(eulere.x), Float(eulere.y), Float(eulere.z))))
}

func getAngleFrom(eulere: SIMD3<Float>) -> Float {
    return getAngleFrom(eulere: SCNVector3(eulere))
}

func getAngleFrom(transform: SCNMatrix4) -> Float {
    let orientation = SCNVector3(transform.m31, transform.m32, transform.m33)
    return atan2f(orientation.x, orientation.z)
}

func getAngleFrom(transform: simd_float4x4) -> Float {
    let orientation = SIMD3<Float>(transform[2][0], transform[2][1], transform[2][2])
    return atan2f(orientation.x, orientation.z)
}

func tan180To360Degree(_ value: Float) -> Float {
    var angl = value
    if angl < 0 {
        angl = -angl
    } else { angl = 360 - angl }
    return angl
}

///Takes two transformation matrices and returns the minimum angle between their Z axes in radians between 0 and PI
func getAngleBetweenTransforms(l: simd_float4x4, r: simd_float4x4) -> Float {
    let firstPoint = SIMD3<Float>(l[2][0], l[2][1], l[2][2])
    let secPoint = SIMD3<Float>(r[2][0], r[2][1], r[2][2])
    
    var angle = abs(atan2f(secPoint.x, secPoint.z) - atan2f(firstPoint.x, firstPoint.z))
    if angle > Float.pi { angle = 2*Float.pi - angle }
    return angle
}

func getTransformPosition(from transform: simd_float4x4) -> SIMD3<Float> {
    return SIMD3<Float>(transform[3][0],
                        transform[3][1],
                        transform[3][2])
}

func getWorldTransform(childPos: SIMD3<Float> = .zero,
                       parentPos: SIMD3<Float> = .zero,
                       parentEuler: SIMD3<Float> = .zero) -> simd_float4x4 {
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

func makeErr(with cwd: codeWithDescr) -> NSError {
    return NSError(domain: "VPS",
                   code: cwd.code,
                   userInfo: [NSLocalizedDescriptionKey: cwd.descr])
}
