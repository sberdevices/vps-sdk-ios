//
//  ConverterGPS.swift
//  VPSNMobile
//
//  Created by Eugene Smolyakov on 07.07.2021.
//

import Foundation
import CoreLocation

public struct PoseVPS:Codable {
    public let position:SIMD3<Double>
    public let rotation:SIMD3<Double>
    
    public init(pos: SIMD3<Double>, rot: SIMD3<Double>) {
        self.position = pos
        self.rotation = rot
    }
}

public struct MapPoseVPS:Codable {
    public let latitude:Double
    public let longitude:Double
    public let course:Double
    public init(lat: Double, long: Double, course: Double) {
        self.latitude = lat
        self.longitude = long
        self.course = course
    }
    
    public func getCllocation() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

public struct GeoReferencing:Codable {
    public let geopoint: MapPoseVPS
    public let coordinate: PoseVPS
    ///negative angle from 0 to 360, clockwise
    public let rotateAngl:Double
    public init(geopoint: MapPoseVPS, coordinate: PoseVPS) {
        self.geopoint = geopoint
        self.coordinate = coordinate
        rotateAngl = GeoReferencing.calculateAngl(geopoint: geopoint, coordinate: coordinate)
    }
    
    public static func initFromUrl(url:URL) -> GeoReferencing? {
        guard let data = try? Data(contentsOf: url),
              let model:GeoReferencing = try? JSONDecoder().decode(GeoReferencing.self, from: data)  else { return nil }
        return model
    }
    
    static func calculateAngl(geopoint: MapPoseVPS, coordinate: PoseVPS) -> Double {
        var vpsangl = getAngleFrom(simd: coordinate.rotation).inDegrees()
        if vpsangl < 0 { vpsangl = -vpsangl }
        else { vpsangl = 360 - vpsangl }
        return -(geopoint.course - vpsangl)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        geopoint = try container.decode(MapPoseVPS.self, forKey: .geopoint)
        coordinate = try container.decode(PoseVPS.self, forKey: .coordinate)
        rotateAngl = GeoReferencing.calculateAngl(geopoint: geopoint, coordinate: coordinate)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(geopoint, forKey: .geopoint)
        try container.encode(coordinate, forKey: .coordinate)
    }
}
extension GeoReferencing {
    enum CodingKeys: CodingKey {
        case geopoint
        case coordinate
    }
}

public class ConverterGPS {
    public private(set) var geoReferencing: GeoReferencing?
    
    public private(set) var status: Status = .waiting
    
    public enum Status {
        case waiting
        case unavalable
        case ready
    }
    
    ///set custom geoReferencing
    public func setGeoreference(geoReferencing:GeoReferencing) {
        self.geoReferencing = geoReferencing
        status = .ready
    }
    
    func setStatusUnavalable() {
        status = .unavalable
    }
    
    ///
    /// - Parameters:
    ///   - point: current point
    /// - Returns: where i am in planet
    public func convertToGPS(point:SIMD3<Double>) -> (lat:Double,long:Double)? {
        guard let geoRef = geoReferencing else {
            return nil
        }
        let rotatedPoint = rotatedCoordinate(angl: geoRef.rotateAngl, point: point)
        let rotatedRef = rotatedCoordinate(angl: geoRef.rotateAngl, point: geoRef.coordinate.position)
        return getCurrentLocationFrom(p1: rotatedRef,
                                      p2: rotatedPoint,
                                      geoPoint: (lat:geoRef.geopoint.latitude,long:geoRef.geopoint.longitude))
    }
    
    /// Get arkit position from geo
    /// - Parameters:
    ///   - geoPoint: target geo coordinate
    /// - Returns: new local coodeinate
    public func convertToXYZ(geoPoint:(lat:Double,long:Double)) -> SIMD3<Double>? {
        guard let geoRef = geoReferencing else {
            return nil
        }
        return getArkitFrom(lastgeo: (lat:geoRef.geopoint.latitude,long:geoRef.geopoint.longitude),
                            p1: geoRef.coordinate.position,
                            angl: -geoRef.rotateAngl,
                            geoPoint: geoPoint)
    }
    
    ///
    /// - Parameters:
    ///   - p1: Init point
    ///   - p2: current point
    ///   - geoPoint: geo coordinates
    /// - Returns: where i am in planet
    func getCurrentLocationFrom(p1      :SIMD3<Double>,
                                p2      :SIMD3<Double>,
                                geoPoint:(lat:Double,long:Double)) -> (lat:Double,long:Double) {
        let dx = p2.x - p1.x
        let dz = p2.z - p1.z
        
        let onelat = 40007.863 * 1000 / 360
        let onelong = cos(geoPoint.lat * Double.pi / 180.0 ) * 40075 / 360 * 1000
        
        let lat = geoPoint.lat - dz / onelat
        let long = geoPoint.long + dx / onelong
        
        return (lat,long)
    }
    
    
    /// Get arkit position from geo
    /// - Parameters:
    ///   - lastgeo: last anchor geo point
    ///   - p1: last position
    ///   - angl: angl to rotate
    ///   - geoPoint: target geo coordinate
    /// - Returns: new local coodeinate
    func getArkitFrom(lastgeo: (lat:Double,long:Double),
                      p1     : SIMD3<Double>,
                      angl   : Double,
                      geoPoint:(lat:Double,long:Double)) -> SIMD3<Double>{
        let onelat = 40007.863 * 1000 / 360
        let onelong = cos(lastgeo.lat * Double.pi / 180.0 ) * 40075 / 360 * 1000
        
        let dz = -(geoPoint.lat - lastgeo.lat) * onelat
        let dx = (geoPoint.long - lastgeo.long) * onelong
        
        let rotateDif = rotatedCoordinate(angl: angl, point: SIMD3<Double>(dx,p1.y,dz))
        let new = SIMD3<Double>(p1.x + rotateDif.x, p1.y, p1.z + rotateDif.z)
        return new
    }
    
    /// Rotate points
    /// - Parameters:
    ///   - angl: angl to rotate
    ///   - x: x
    ///   - z: z
    /// - Returns: rotated points
    func rotatedCoordinate(angl:Double, point:SIMD3<Double>) -> SIMD3<Double> {
        let rad = (angl) * Double.pi / 180.0
        let newX = (point.x)*cos(rad) + (point.z)*sin(rad)
        let newZ = (point.x)*sin(rad) - (point.z)*cos(rad)
        return SIMD3<Double>(newX, point.y, -newZ)
    }
}


