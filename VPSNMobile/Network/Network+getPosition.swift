

import Foundation
protocol NetVPSService {
    func singleLocalize(photo: UploadVPSPhoto,
                        success: ((ResponseVPSPhoto) -> Void)?,
                        failure: ((NSError) -> Void)?)
    func serialLocalize(reqs: [UploadVPSPhoto],
                        success: ((ResponseVPSPhoto) -> Void)?,
                        failure: ((NSError) -> Void)?)
    func downloadNeuroModel(url: ((URL) -> Void)?,
                            downProgr: ((Double) -> Void)?,
                            failure: ((NSError) -> Void)?)
}

extension Network: NetVPSService {
    func singleLocalize(photo: UploadVPSPhoto,
                        success: ((ResponseVPSPhoto) -> Void)?,
                        failure: ((NSError) -> Void)?) {
        let bodyCreator = RequestBodyCreator(apiVersion: self.APIversion)
        bodyCreator.addToBody(photo: photo, metaKey: "json", imageKey: "image", featuresKey: "embedding")
        let req = bodyCreator.getBody()
        uploadMultipart(url: baseURL, body: req.body, boundary: req.boundary) { (resp) in
            if let model = parseVPSResponse(from: resp) {
                success?(model)
            }
        } failure: { (err) in
            failure?(err)
        }
    }
    func serialLocalize(reqs: [UploadVPSPhoto],
                        success: ((ResponseVPSPhoto) -> Void)?,
                        failure: ((NSError) -> Void)?) {
        let bodyCreator = RequestBodyCreator(apiVersion: self.APIversion)
        for (num, item) in reqs.enumerated() {
            bodyCreator.addToBody(photo: item, metaKey: "mes\(num)", imageKey: "mes\(num)", featuresKey: "embd\(num)")
        }
        let req = bodyCreator.getBody()
        uploadMultipart(url: firstLocateUrl, body: req.body, boundary: req.boundary) { (resp) in
            if let model = parseVPSResponse(from: resp) {
                success?(model)
            }
        } failure: { (err) in
            failure?(err)
        }
    }
    
    func downloadNeuroModel(url: ((URL) -> Void)?,
                            downProgr: ((Double) -> Void)?,
                            failure: ((NSError) -> Void)?) {
        downloadNeuro { (path) in
            url?(path)
        } downProgr: { (progr) in
            downProgr?(progr)
        } failure: { (err) in
            failure?(err)
        }
    }
}
