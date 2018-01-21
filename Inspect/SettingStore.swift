//
//  SettingStore.swift
//  Inspect
//
//  Created by Tao Xu on 1/21/18.
//  Copyright © 2018 fourplex. All rights reserved.
//

import Foundation

let kMITMDetection = "MITMDetection"

extension UserDefaults {
    static func getMITMDetection() -> Bool {
        return shared.bool(forKey: kMITMDetection)
    }

    static func setMITMDetection(_ enable: Bool) {
        shared.set(enable, forKey: kMITMDetection)
        shared.synchronize()
    }
}
