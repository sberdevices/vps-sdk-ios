

import Foundation

final class MultipartDataCreator {
    private(set) var body = Data()
    let boundary = "Boundary-\(NSUUID().uuidString)"
    private let lineBreak = "\r\n"
    
    func bodyAdd(data: Data,
                 key: String,
                 fileName: String? = nil,
                 mimeType: String? = nil) {
        body.append("--\(boundary + lineBreak)")
        var disposition = "Content-Disposition: form-data; name=\"\(key)\""
        if let fileName = fileName { disposition += "; filename=\"\(fileName)\"\(lineBreak)" }
        else { disposition.append("\(lineBreak + lineBreak)") }
        body.append(disposition)
        if let mimeType = mimeType {
            body.append("Content-Type: \(mimeType + lineBreak + lineBreak)")
        }
        
        body.append(data)
        body.append(lineBreak)
    }
    
    func getBody() -> Data {
        body.append("--\(boundary)--\(lineBreak)")
        return body
    }
    
}

///
final class RequestBodyCreator {
    private let multipartCreator = MultipartDataCreator()
    var APIVersion: Int
    
    init(apiVersion: Int) {
        self.APIVersion = apiVersion
    }
    
    func getBody() -> (body: Data, boundary: String) {
        return (multipartCreator.getBody(), multipartCreator.boundary)
    }
    
    func addToBody(photo: UploadVPSPhoto, metaKey: String, imageKey: String = "", featuresKey: String = "") {
        let params = getParams(from: photo)
        if let data = try? JSONSerialization.data(withJSONObject: params,
                                                  options: [.fragmentsAllowed]) {
            multipartCreator.bodyAdd(data: data, key: metaKey)
        }
        if let img = photo.image {
            let media = Media(withImage: img, forKey: imageKey)
            multipartCreator.bodyAdd(data: media.data, key: media.key, fileName: media.filename, mimeType: media.mimeType)
        }
        if let neuro = photo.features {
            multipartCreator.bodyAdd(data: neuro.getData(), key: featuresKey, fileName: neuro.filename, mimeType: neuro.mimeType)
        }
    }
    
    func getParams(from photo: UploadVPSPhoto) -> [String: Any] {
        let trackingPose = ["x": photo.locPosX,
                            "y": photo.locPosY,
                            "z": photo.locPosZ,
                            
                            "rx": photo.locPosPitch,
                            "ry": photo.locPosYaw,
                            "rz": photo.locPosRoll
                            
        ]
        var location = [:] as [String : Any]
        if let comp = photo.compas {
            let compass = ["heading": comp.heading,
                           "accuracy": comp.acc,
                           "timestamp": comp.timestamp]
            location["compass"] = compass
        }
        if let gps = photo.gps {
            let gps = ["latitude": gps.lat,
                       "longitude": gps.long,
                       "altitude": gps.alt,
                       "accuracy": gps.acc,
                       "timestamp": gps.timestamp]
            location["gps"] = gps
        }
        let intrinsics = ["fx": photo.instrinsicsFX,
                          "fy": photo.instrinsicsFY,
                          "cx": photo.instrinsicsCX,
                          "cy": photo.instrinsicsCY]
        var attributes = ["client_coordinate_system": photo.locationClientCoordSystem,
                          "intrinsics": intrinsics,
                          "user_id": photo.clientID,
                          "session_id": photo.sessionID,
                          "tracking_pose": trackingPose,
                          "timestamp": photo.timestamp] as [String : Any]
        if !location.isEmpty {
            attributes["location"] = location
        }
        let data = ["id": photo.jobID,
                    "attributes": attributes] as [String : Any]
        let datakey = ["data": data] as [String : Any]
//        print("senddadta",datakey as NSDictionary)
        return datakey
    }
}
