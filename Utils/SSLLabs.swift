//
//  SSLLabs.swift
//  Inspect
//
//  Created by hewig on 1/3/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import Foundation

// API docs https://github.com/ssllabs/ssllabs-scan/blob/master/ssllabs-api-docs.md
open class SSLLabs {
    static let testUrl = "https://www.ssllabs.com/ssltest/analyze.html?d="
    static func scanUrl(_ host: String) -> URL? {
        let url = SSLLabs.testUrl + host
        return URL(string: url)
    }

    //todo analyze API
    //https://api.ssllabs.com/api/v2/analyze?host=kyfw.12306.cn

    //todo endpoint API
    //https://api.ssllabs.com/api/v2/getEndpointData?host=www.ssllabs.com&s=64.41.200.100
}
