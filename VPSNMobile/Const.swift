
import Foundation

struct Const {
    static let motionAngle: Double = 40
    static let os = "iOS"
    static let domain = "ServiceVPS"
    // error codes
    struct Err {
        static let kNet = -100
        static let kNetAuth = -101
        struct Fields {
            static let data = "data"
            static let defDescr = "default_description"
            static let kindOfErr = "error"
        }
    }
}

struct ModelsFolder {
    static let name = "TFModels"
}
