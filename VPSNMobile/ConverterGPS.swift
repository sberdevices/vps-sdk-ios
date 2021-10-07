

import Foundation
import CoreLocation
import simd
/// Local coordinate in vps
public struct PoseVPS: Codable {
    public let transform: simd_float4x4
    public var position: SIMD3<Float> {
        get {
            return SIMD3<Float>(transform[3][0],transform[3][1],transform[3][2])
        }
    }
    /// Euler angl in degree
    public var rotation: SIMD3<Float> {
        get {
            let rot = getEulereFrom(transform: transform)
            return SIMD3(rot.x.inDegrees(),rot.y.inDegrees(),rot.z.inDegrees())
        }
    }
    
    /// - Warning: may be subject to gimblock
    public init(pos: SIMD3<Float>, rot: SIMD3<Float>) {
        self.transform = getTransformFrom(eulere: SIMD3(rot.x.inRadians(),
                                                        rot.y.inRadians(),
                                                        rot.z.inRadians()),
                                          position: pos)
    }
    
    public init(transform: simd_float4x4) {
        self.transform = transform
    }
    
    enum CodingKeys: String, CodingKey {
            case position
            case rotation
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let position = try values.decode(SIMD3<Float>.self, forKey: .position)
        let rotation = try values.decode(SIMD3<Float>.self, forKey: .rotation)
        self.transform = getTransformFrom(eulere: SIMD3(rotation.x.inRadians(),
                                                        rotation.y.inRadians(),
                                                        rotation.z.inRadians()),
                                          position: position)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(position, forKey: .position)
        try container.encode(rotation, forKey: .rotation)
    }
}

/// World Map coordinate
public struct MapPoseVPS:Codable {
    public let latitude: Double
    public let longitude: Double
    public let course: Double
    public init(lat: Double, long: Double, course: Double) {
        self.latitude = lat
        self.longitude = long
        self.course = course
    }
    
    public func getCllocation() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Anchor point for converting coordinates
public struct GeoReferencing: Codable {
    public let geopoint: MapPoseVPS
    public let coordinateVPS: PoseVPS
    public init(geopoint: MapPoseVPS, coordinate: PoseVPS) {
        self.geopoint = geopoint
        self.coordinateVPS = coordinate
    }
    
    public static func initFromUrl(url:URL) -> GeoReferencing? {
        guard let data = try? Data(contentsOf: url),
              let model: GeoReferencing = try? JSONDecoder().decode(GeoReferencing.self, from: data)  else { return nil }
        return model
    }
}

/// It is used for easy conversion of earth coordinates to coordinates in vps. An anchor point is required, which is taken automatically from a successful localization or a custom one is set
public class ConverterGPS {
    public init() {}
    public private(set) var geoReferencing: GeoReferencing?
    ///negative angle from 0 to 360, clockwise
    private(set) var rotateAngl:Float?
    public private(set) var status: Status = .waiting
    
    public enum Status:Error {
        case waiting
        case unavalable
        case ready
    }
    
    /// set custom geoReferencing
    public func setGeoreference(geoReferencing:GeoReferencing) {
        self.geoReferencing = geoReferencing
        rotateAngl = calculateAngl(geopoint: geoReferencing.geopoint, coordinate: geoReferencing.coordinateVPS)
        status = .ready
    }
    
    func setStatusUnavalable() {
        status = .unavalable
    }
    
    ///
    /// - Parameters:
    ///   - point: current point
    /// - Warning: it is not recommended to use init(pos: SIMD3(Float), rot: SIMD3(Float)) for posevps may be subject to gimblock
    /// - Returns: where i am in planet
    public func convertToGPS(pose:PoseVPS) throws -> MapPoseVPS {
        guard let geoRef = geoReferencing, let rotateAngl = rotateAngl else {
            throw status
        }
        let poseAngl = getAngleFrom(transform: pose.transform).inDegrees()
        return calculateMapPoseForConverter(pos: pose.position,
                                            poseAngl: poseAngl,
                                            geoRef: geoRef,
                                            rotateAngl: rotateAngl)
    }
    
    private func calculateMapPoseForConverter(pos: SIMD3<Float>,
                                              poseAngl: Float,
                                              geoRef: GeoReferencing,
                                              rotateAngl: Float) -> MapPoseVPS {
        let rotatedPoint = rotatedCoordinate(angl: rotateAngl, point: pos)
        let rotatedRef = rotatedCoordinate(angl: rotateAngl, point: geoRef.coordinateVPS.position)
        let loc =  getCurrentLocationFrom(p1: rotatedRef,
                                      p2: rotatedPoint,
                                      geoPoint: (lat:geoRef.geopoint.latitude, long:geoRef.geopoint.longitude))
        let pose360Angl = tan180To360Degree(poseAngl)
        var course = pose360Angl - rotateAngl
        // some maps cant work with value x<0 or 360>x
        if course > 360 { course = course - 360 }
        if course < 0 { course = course + 360 }
        return MapPoseVPS(lat: loc.lat, long: loc.long, course: Double(course))
    }
    
    /// Get arkit position from geo
    /// - Parameters:
    ///   - geoPoint: target geo coordinate
    /// - Returns: new local coodeinate
    public func convertToXYZ(mapPose: MapPoseVPS) throws -> PoseVPS {
        guard let geoRef = geoReferencing, let rotateAngl = rotateAngl else {
            throw status
        }
        let yAngl = -Float(mapPose.course) + (-rotateAngl)
        let coord = getArkitFrom(lastgeo: (lat:geoRef.geopoint.latitude,
                                      long:geoRef.geopoint.longitude),
                            p1: geoRef.coordinateVPS.position,
                            angl: -rotateAngl,
                            geoPoint: (mapPose.latitude,
                                       mapPose.longitude))
        return PoseVPS(pos: coord, rot: SIMD3<Float>(0, yAngl, 0))
    }
    
    func calculateAngl(geopoint: MapPoseVPS, coordinate: PoseVPS) -> Float {
        let angl = getAngleFrom(transform: coordinate.transform).inDegrees()
        let vpsangl = tan180To360Degree(angl)
        return -(Float(geopoint.course) - vpsangl)
    }
    
    ///
    /// - Parameters:
    ///   - p1: Init point
    ///   - p2: current point
    ///   - geoPoint: geo coordinates
    /// - Returns: where i am in planet
    /// - We calculate the difference in meters by how much we have gone from the anchor point. Add to the value of latitude and longitude the value of the difference (meters / 1 value of latitude or longitude)
    func getCurrentLocationFrom(p1: SIMD3<Float>,
                                p2: SIMD3<Float>,
                                geoPoint: (lat: Double, long: Double)) -> (lat: Double, long: Double) {
        let dx = Double(p2.x - p1.x)
        let dz = Double(p2.z - p1.z)
        
        /// Latitude. The circumference is different - 40.075.696 km at the equator, 0 at the poles. Calculated as the length of one degree at the equator times the cosine of the latitude angle. One degree at the equator - 40,075.696 km / 360 ° = 111.321377778 km / ° (111321.377778 m / °)
        let onelat = Earth.meridianInMtr / 360
        /// Longitude. Everything is simple here: the circumference (meridian) is constant - 40,008 km, divide by 360 °, we get:111.134861111 km in one degree, we divide by 60 minutes:1.85224768519 km in one minute, divided by 60 seconds:0.0308707947531 km (30.8707947531 m) in one second.
        let onelong = cos(geoPoint.lat * Double.pi / 180.0 ) * Earth.parallelsInMtr / 360
        
        let lat = geoPoint.lat - dz / onelat
        let long = geoPoint.long + dx / onelong
        
        return (lat, long)
    }
    
    
    /// Get arkit position from geo
    /// - Parameters:
    ///   - lastgeo: last anchor geo point
    ///   - p1: last position
    ///   - angl: angl to rotate
    ///   - geoPoint: target geo coordinate
    /// - Returns: new local coodeinate
    /// - Calculate the difference in meters between the new point and the geo anchor point. Add it to the anchor values x and z
    func getArkitFrom(lastgeo: (lat: Double, long: Double),
                      p1: SIMD3<Float>,
                      angl: Float,
                      geoPoint: (lat: Double,long: Double)) -> SIMD3<Float> {
        /// Latitude. The circumference is different - 40.075.696 km at the equator, 0 at the poles. Calculated as the length of one degree at the equator times the cosine of the latitude angle. One degree at the equator - 40,075.696 km / 360 ° = 111.321377778 km / ° (111321.377778 m / °)
        let onelat = Earth.meridianInMtr / 360
        /// Longitude. Everything is simple here: the circumference (meridian) is constant - 40,008 km, divide by 360 °, we get:111.134861111 km in one degree, we divide by 60 minutes:1.85224768519 km in one minute, divided by 60 seconds:0.0308707947531 km (30.8707947531 m) in one second.
        let onelong = cos(lastgeo.lat * Double.pi / 180.0 ) * Earth.parallelsInMtr / 360
        
        let dz = -(geoPoint.lat - lastgeo.lat) * onelat
        let dx = (geoPoint.long - lastgeo.long) * onelong
        
        let rotateDif = rotatedCoordinate(angl: angl, point: SIMD3(Float(dx),p1.y,Float(dz)))
        let new = SIMD3<Float>(p1.x + rotateDif.x, p1.y, p1.z + rotateDif.z)
        return new
    }
    
    /// Rotate points
    /// - Parameters:
    ///   - angl: angl to rotate
    ///   - x: x
    ///   - z: z
    /// - Returns: rotated points
    func rotatedCoordinate(angl: Float, point: SIMD3<Float>) -> SIMD3<Float> {
        let rad = (angl) * Float.pi / 180.0
        let newX = (point.x)*cos(rad) + (point.z)*sin(rad)
        let newZ = (point.x)*sin(rad) - (point.z)*cos(rad)
        return SIMD3<Float>(newX, point.y, -newZ)
    }
}

fileprivate struct Earth {
    /// Circumference  equatorial from wiki
    static let meridianInMtr = 40007.863 * 1000
    /// Circumference  meridional from wiki
    static let parallelsInMtr = 40075.0 * 1000
}
