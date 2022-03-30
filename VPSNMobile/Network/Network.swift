

import UIKit

class Network: NSObject {
    var session = URLSession.shared
    var APIversion = 1
    var baseURL = ""
    var settings: Settings
    
    init(settings: Settings) {
        self.settings = settings
        super.init()
        baseURL = "\(settings.url)vps/api/v2"
    }
    
    var observation: NSKeyValueObservation!
    func download(url:String,
                  outputURL: @escaping ((URL) -> Void),
                  downProgr: @escaping ((Double) -> Void),
                  failure: @escaping ((NSError) -> Void)) {
        put { [weak self] in
            let task = self?.session.downloadTask(with: URL(string: url)!, completionHandler: { (URL, Responce, Error) in
                if let err = Error {
                    self?.f(err as NSError, failure)
                    self?.executeNext()
                }
                if let path = URL {
                    outputURL(path)
                    self?.executeNext()
                }
            })
            task?.resume()
            self?.observation = task?.progress.observe(\.fractionCompleted) { progress, _ in
                self?.s(progress.fractionCompleted, downProgr)
            }
        }
    }
    
    func uploadMultipart(url: String,
                         body: Data,
                         boundary: String,
                         success: @escaping ((NSDictionary) -> Void),
                         failure: @escaping ((NSError) -> Void)) {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.timeoutInterval = settings.timeOutDuration
        put { [weak self] in
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            self?.session.dataTask(with: request) { (data, response, error) in
                if let err = error {
                    self?.f(err as NSError, failure)
                    self?.executeNext()
                }
//                if let response = response {
//                                    print("resp",response)
//                }
                if let data = data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
//                                            print("json",json)
                        self?.commonParsingResponse(
                            (data: json, response: response),
                            success: { (ans) in
//                                                            print("ans",ans)
                                if ans.count > 0 {
                                    self?.s(ans[0], success)
                                    self?.executeNext()
                                } else {
                                }
                        }) { (err) in
                            print("err", err)
                            self?.f(err, failure)
                            self?.executeNext()
                        }
                    } catch {
                        self?.f(error as NSError, failure)
                        self?.executeNext()
                    }
                }
            }.resume()
        }
    }
    
    private func commonParsingResponse(_ response: (data: NSDictionary?, response: URLResponse?),
                                       success: ([NSDictionary]) -> Void,
                                       failure: ((NSError) -> Void)?) {
        var headerError: NSError?
        if let resp = response.response as? HTTPURLResponse {
            headerError = checkStatusCode(resp.statusCode)
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
                if let err = json["error"] as? String {
                    errCode = err
                }
                let errDescription: String
                var defDescr = ""
                if let message = json["message"] as? NSDictionary {
                    errDescription = localizedDescriptionFrom(dict: message)
                    defDescr = defaultDescriptionFrom(dict: message)
                } else if let message = json["message"] as? String {
                    errDescription = message
                    defDescr = message
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
                } else if errCode.count > 0 {
                    switch errCode {
                    // describe all other codes if needed
                    default:
                        code = Const.Err.kNet
                    }
                } else {
                    if defDescr.contains("authorization") {
                        code = Const.Err.kNetAuth
                    } else {
                        code = Const.Err.kNet
                    }
                }
                err = NSError(domain: Const.domain,
                              code: code,
                              userInfo: [
                                Const.Err.Fields.data: errData as Any,
                                Const.Err.Fields.kindOfErr: errCode,
                                Const.Err.Fields.defDescr: defDescr,
                                NSLocalizedDescriptionKey: errDescription
                ])
            } else {
                statusOk = true
            }
            if statusOk {
                if let data = data {
                    success(data)
                } else { // try to parse it somewhere else:
                    success([json])
                }
            } else {
                if let err = err {
                    failure?(err)
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
        if let failure = failure {
            let error = NSError(domain: Const.domain,
                                code: Const.Err.kNet,
                                userInfo: [NSLocalizedDescriptionKey: descr])
            failure(error)
        }
    }
    private func localizedDescriptionFrom(dict: NSDictionary, field: String) -> String {
        if let field = dict[field] as? String {
            return field
        } else if let field = dict[field] as? [String] {
            return field.joined(separator: "\n")
        } else if let field = dict[field] as? [NSDictionary] {
            var out = ""
            for dict in field {
                let str = localizedDescriptionFrom(dict: dict)
                if out.count > 0 {
                    out += "\n"
                }
                out.append(contentsOf: str)
            }
            return out
        } else if let dict = dict[field] as? NSDictionary {
            return localizedDescriptionFrom(dict: dict)
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
            error = nil
//            error = NSError(domain: Const.domain,
//                            code: Const.err.kNetAuth,
//                            userInfo: [NSLocalizedDescriptionKey: "Authorization failure".localized])
        default:
            error = NSError(domain: Const.domain,
                            code: Const.Err.kNet,
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
        return { err in
            DispatchQueue.main.async {
                failure?(err)
            }
        }
    }

    private func executeNext() {
        queue.addOperation { [weak self] in
            let opp: (() -> Void)?
            self?.lock.lock()
            opp = self?.operations.popLast()
            self?.lock.unlock()
            if let opp = opp {
                opp()
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
