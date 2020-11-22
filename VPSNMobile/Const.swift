//
//  Const.swift
//  VPS
//
//  Created by Eugene Smolyakov on 03.09.2020.
//  Copyright © 2020 ES. All rights reserved.
//

import Foundation

struct Const {
    static let os = "iOS"
    static let domain = "ServiceVPS"
    // error codes
    struct err {
        static let kNet = -100
        static let kNetAuth = -101
        struct fields {
            static let data = "data"
            static let defDescr = "default_description"
            static let kindOfErr = "error"
        }
    }
}

struct ModelsFolder {
    static let name = "TFModels"
}
