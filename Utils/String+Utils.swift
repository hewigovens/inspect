//
//  String+Utils.swift
//  Inspect
//
//  Created by hewig on 11/5/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import Foundation

extension String {
    var range: NSRange {
        return NSRange(location: 0, length: self.count)
    }
}

extension String {
    var length: Int {
        return self.lengthOfBytes(using: .utf8)
    }
}
