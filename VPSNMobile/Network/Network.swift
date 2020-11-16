//
//  Network.swift
//  VPS
//
//  Created by Eugene Smolyakov on 03.09.2020.
//  Copyright © 2020 ES. All rights reserved.
//

import UIKit

class Network: NSObject {
    static let sharedInstance = Network()
    let session = URLSession.shared
    
    private let baseURL = "http://api.polytech.vps.arvr.sberlabs.com/vps/api/v1/job"
    
    func get(photo:UploadVPSPhoto,
             success: @escaping ((ResponseVPSPhoto) -> Void),
             failure: @escaping ((NSError) -> Void)) {
        let params = getParams(from: photo)
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        
        let boundary = generateBoundary()
        
        put { [weak self] in
            let media = Media(withImage: photo.image, forKey: "image")
            
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            let dataBody = self?.createDataBody(withParameters: params, media: [media], boundary: boundary)
            request.httpBody = dataBody
            self?.session.dataTask(with: request) { (data, response, error) in
                if let response = response {
                    //                print("resp",response)
                }
                
                if let data = data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
                        //                    print("json",json)
                        self?.commonParsingResponse(
                            (data: json, response: response),
                            success: { (ans) in
                                //                            print("ans",ans)
                                if ans.count > 0 {
                                    if let model = parseVPSResponse(from: ans[0]) {
                                        self?.s(model, success)
                                        self?.executeNext()
                                    }
                                } else {
                                    
                                }
                        }) { (err) in
                            print("err",err)
                            self?.f(err, failure)
                            self?.executeNext()
                        }
                    } catch {
                        print(error)
                        self?.f(error as NSError, failure)
                        self?.executeNext()
                    }
                }
            }.resume()
        }
        
        
    }
    
    private func createDataBody(withParameters params: [String:Any], media: [Media], boundary: String) -> Data {
        
        let lineBreak = "\r\n"
        var body = Data()
        for (key, value) in params {
            if let d = value as? NSDictionary {
                if let data = try? JSONSerialization.data(withJSONObject: d,
                                                          options: []) {
                    body.append("--\(boundary + lineBreak)")
                    body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak + lineBreak)")
                    body.append(data)
                    body.append(lineBreak)
                }
            }
        }
        
        
        for photo in media {
            body.append("--\(boundary + lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(photo.key)\"; filename=\"\(photo.filename)\"\(lineBreak)")
            body.append("Content-Type: \(photo.mimeType + lineBreak + lineBreak)")
            body.append(photo.data)
            body.append(lineBreak)
        }
        
        
        body.append("--\(boundary)--\(lineBreak)")
        
        return body
    }
    
    private func getParams(from photo:UploadVPSPhoto)->[String:Any] {
        let localPos = ["x":photo.locPosX,
                        "y":photo.locPosY,
                        "z":photo.locPosZ,
                        "roll":photo.locPosRoll,
                        "pitch":photo.locPosPitch,
                        "yaw":photo.locPosYaw
        ]
        var location = ["type":photo.locationType,
                        "location_id":photo.locationID,
                        "clientCoordinateSystem":photo.locationClientCoordSystem,
                        "localPos":localPos] as [String : Any]
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
        let imtransform = ["orientation":photo.imageTransfOrientation,
                           "mirrorX":photo.imageTransfMirrorX,
                           "mirrorY":photo.imageTransfMirrorY] as [String : Any]
        let intrinsics = ["fx":photo.instrinsicsFX,
                          "fy":photo.instrinsicsFY,
                          "cx":photo.instrinsicsCX,
                          "cy":photo.instrinsicsCY]
        let attributes = ["location":location,
                          "imageTransform":imtransform,
                          "intrinsics":intrinsics,
                          "forced_localization":photo.forceLocalization] as [String : Any]
        let data = ["id":photo.job_id,
                    "type":"job",
                    "attributes":attributes] as [String : Any]
        let json = ["data":data]
        let parameters = ["json":json] as [String : Any]
        print("json",parameters as NSDictionary)
        return parameters
    }
    
    private func generateBoundary() -> String {
        return "Boundary-\(NSUUID().uuidString)"
    }
    
    private func commonParsingResponse(_ response: (data:NSDictionary?, response:URLResponse?),
                                       success: ([NSDictionary]) -> Void,
                                       failure: ((NSError) -> Void)?) {
        var headerError: NSError?
        if let c = response.response as? HTTPURLResponse {
            headerError = checkStatusCode(c.statusCode)
        }
        if let json = response.data {
            var err: NSError? = nil
            let unwrap = { (json: NSDictionary, field: String) -> [NSDictionary]? in
                if let res = json[field] as? NSDictionary {
                    return [res]
                } else if let res = json[field] as? [NSDictionary] {
                    return res
                } else if json[field] != nil { // it's a concrete data type (like Bool, String etc)
                    return [json]
                } else {
                    return nil
                }
            }
            let data = unwrap(json, "data")
            let statusOk: Bool
            // do we have any hints about error execution?
            if data == nil || headerError != nil {
                statusOk = false
                let code: Int
                let errData = unwrap(json, "data")
                var errCode = ""
                if let c = json["error"] as? String {
                    errCode = c
                }
                let errDescription: String
                var defDescr = ""
                if let d = json["message"] as? NSDictionary {
                    errDescription = localizedDescriptionFrom(dict: d)
                    defDescr = defaultDescriptionFrom(dict: d)
                } else if let d = json["message"] as? String {
                    errDescription = d
                    defDescr = d
                } else {
                    if let hdr = headerError {
                        errDescription = hdr.localizedDescription
                    } else {
                        errDescription = "Error description isn't provided".localized
                    }
                }
                // package header's code have a priority
                // over the body's error code:
                if let hdr = headerError {
                    code = hdr.code
                }
                else if errCode.count > 0 {
                    switch errCode {
                    // describe all other codes if needed
                    default:
                        code = Const.err.kNet
                    }
                } else {
                    if defDescr.contains("authorization") {
                        code = Const.err.kNetAuth
                    } else {
                        code = Const.err.kNet
                    }
                }
                err = NSError(domain: Const.domain,
                              code: code,
                              userInfo: [
                                Const.err.fields.data: errData as Any,
                                Const.err.fields.kindOfErr: errCode,
                                Const.err.fields.defDescr: defDescr,
                                NSLocalizedDescriptionKey: errDescription
                ])
            } else {
                statusOk = true
            }
            if statusOk {
                if let d = data {
                    success(d)
                } else { // try to parse it somewhere else:
                    success([json])
                }
            } else {
                if let e = err {
                    failure?(e)
                } else {
                    handle(failure: failure, descr: "Cannot parse json".localized)
                }
            }
            
        } else {
            if let hdr = headerError {
                failure?(hdr)
            } else {
                handle(failure: failure, descr: "No Network Connection".localized)
            }
        }
    }
    
    private func handle(failure: ((NSError) -> Void)?, descr: String) {
        if let f = failure {
            let error = NSError(domain: Const.domain,
                                code: Const.err.kNet,
                                userInfo: [NSLocalizedDescriptionKey: descr])
            f(error)
        }
    }
    private func localizedDescriptionFrom(dict: NSDictionary, field: String) -> String {
        if let d = dict[field] as? String {
            return d
        } else if let d = dict[field] as? [String] {
            return d.joined(separator: "\n")
        } else if let dd = dict[field] as? [NSDictionary] {
            var out = ""
            for d in dd {
                let e = localizedDescriptionFrom(dict: d)
                if out.count > 0 {
                    out += "\n"
                }
                out.append(contentsOf: e)
            }
            return out
        } else if let d = dict[field] as? NSDictionary {
            return localizedDescriptionFrom(dict: d)
        }
        return ""
    }

    private func localizedDescriptionFrom(dict: NSDictionary) -> String {
        if let locale = NSLocale.current.languageCode {
            if let localized = dict[locale.lowercased()] as? String {
                return localized
            } else {
                return defaultDescriptionFrom(dict: dict)
            }
        }
        return ""
    }
    
    private func defaultDescriptionFrom(dict: NSDictionary) -> String {
        if let en = dict["en"] as? String { // a default value
            return en
        }
        return ""
    }
    
    private func checkStatusCode(_ status: Int) -> NSError? {
        let error: NSError?
        switch (status) {
        case 200:
            error = nil
        case 401:
            error = NSError(domain: Const.domain,
                            code: Const.err.kNetAuth,
                            userInfo: [NSLocalizedDescriptionKey: "Authorization failure".localized])
        default:
            error = NSError(domain: Const.domain,
                            code: Const.err.kNet,
                            userInfo: [NSLocalizedDescriptionKey: "Network failure".localized])
        }
        return error
    }
    
    private func put(_ op: @escaping (() -> Void)) {
        lock.lock()
        operations.append(op)
        lock.unlock()
        executeNext()
    }

    private func s<T>(_ ans: T, _ success: ((T) -> Void)?) {
        DispatchQueue.main.async {
            success?(ans)
        }
    }

    private func f(_ err: NSError, _ failure: ((NSError) -> Void)?) {
        DispatchQueue.main.async {
            failure?(err)
        }
    }

    internal func errHandler(_ failure: ((NSError) -> Void)?) -> ((NSError) -> Void) {
        return { e in
            DispatchQueue.main.async {
                failure?(e)
            }
        }
    }

    private func executeNext() {
        queue.addOperation { [weak self] in
            let opp: (() -> Void)?
            self?.lock.lock()
            opp = self?.operations.popLast()
            self?.lock.unlock()
            if let op = opp {
                op()
            }
        }
    }

    private lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "NetFun Queue"
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private lazy var operations = [() -> Void]()
    internal var user = ""
    private let lock = NSLock()
}



