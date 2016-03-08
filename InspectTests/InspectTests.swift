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

    private lazy var data: NSData = NSData(contentsOfFile: NSBundle(forClass: InspectTests.self).pathForResource("mac_dev", ofType: "cer")!)!

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testParseX509() {
        let certificate = SecCertificateCreateWithData(nil, self.data)
        let cert = X509Certificate(certificate: certificate!)
        XCTAssert(cert.subjectName.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0)
        print(cert.description)
    }
}
