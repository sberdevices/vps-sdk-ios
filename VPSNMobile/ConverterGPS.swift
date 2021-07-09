//
//  ConverterGPS.swift
//  VPSNMobile
//
//  Created by Eugene Smolyakov on 07.07.2021.
//

import Foundation
import CoreLocation

public struct GeoReferencing {
    public let geopoint:    (lat:Double,long:Double)
    public let coordinate:  SIMD3<Double>
    public init(geopoint:(lat:Double,long:Double), coordinate:SIMD3<Double>) {
        self.geopoint = geopoint
        self.coordinate = coordinate
    }
}

public class ConverterGPS {
    public private(set) var angl:Double?
    public private(set) var geoReferencing: GeoReferencing?
    
    public enum Errors {
        case setupAngl
        case setupGeoref
    }
    
    public func checkStatus() -> [Errors] {
        var arr = [Errors]()
        if angl == nil { arr.append(.setupAngl) }
        if geoReferencing == nil {arr.append(.setupGeoref)}
        return arr
    }
    
    ///set custom angle
    public func setAngl(angl:Double) {
        self.angl = angl
    }
    ///set custom geoReferencing
    public func setGeoreference(geoReferencing:GeoReferencing) {
        self.geoReferencing = geoReferencing
    }
    
    ///
    /// - Parameters:
    ///   - point: current point
    /// - Returns: where i am in planet
    public func convertToGPS(point:SIMD3<Double>) -> (lat:Double,long:Double)? {
        guard let geoRef = geoReferencing, let angl = angl else {
            return nil
        }
        let rotatedPoint = rotatedCoordinate(angl: angl, point: point)
        let rotatedRef = rotatedCoordinate(angl: angl, point: geoRef.coordinate)
        return getCurrentLocationFrom(p1: rotatedRef, p2: rotatedPoint, geoPoint: geoRef.geopoint)
    }
    
    /// Get arkit position from geo
    /// - Parameters:
    ///   - geoPoint: target geo coordinate
    /// - Returns: new local coodeinate
    public func convertToXYZ(geoPoint:(lat:Double,long:Double)) -> SIMD3<Double>? {
        
        guard let geoRef = geoReferencing, let angl = angl else {
            return nil
        }
        return getArkitFrom(lastgeo: geoRef.geopoint, p1: geoRef.coordinate, angl: -angl, geoPoint: geoPoint)
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


