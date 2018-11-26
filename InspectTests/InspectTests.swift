//
//  InspectTests.swift
//  InspectTests
//
//  Created by hewig on 12/28/15.
//  Copyright © 2015 fourplex. All rights reserved.
//

import XCTest
@testable import Inspect

class InspectTests: XCTestCase {

    lazy var data: Data? = {
        let url = Bundle(for: InspectTests.self).url(forResource: "mac_dev", withExtension: "cer")!
        let data = try? Data(contentsOf: url)
        return data
    }()

    func testParseX509() {
        guard let data = self.data else {
            fatalError("read mac_dev.cer failed")
        }
        let certificate = SecCertificateCreateWithData(nil, data as CFData)
        let cert = X509Certificate(certificate: certificate!)
        XCTAssert(cert.subjectName.lengthOfBytes(using: String.Encoding.utf8) > 0)
        print(cert.description)
    }
}
