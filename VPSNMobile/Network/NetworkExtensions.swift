

import Foundation
protocol NetVPSService {
    func singleLocalize(photo: UploadVPSPhoto,
                        success: ((ResponseVPSPhoto) -> Void)?,
                        failure: ((NSError) -> Void)?)
    func download(url:String,
                  outputURL: ((URL) -> Void)?,
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
    
    func download(url:String,
                  outputURL: ((URL) -> Void)?,
                  downProgr: ((Double) -> Void)?,
                  failure: ((NSError) -> Void)?) {
        download(url: url) { (path) in
            outputURL?(path)
        } downProgr: { (progr) in
            downProgr?(progr)
        } failure: { (err) in
            failure?(err)
        }
    }
}
