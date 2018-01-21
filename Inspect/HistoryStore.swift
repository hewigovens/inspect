//
//  HistoryStore.swift
//  Inspect
//
//  Created by Tao Xu on 10/8/17.
//  Copyright © 2017 fourplex. All rights reserved.
//

import Foundation

extension UserDefaults {
    static let shared = UserDefaults.init(suiteName: kInspectGroupId)!
}

extension UserDefaults {
    static func add(host: String) {
        var history = shared.stringArray(forKey: kHistoryKey) ?? [String]()
        if let index = history.index(of: host) {
            history.remove(at: index)
        }
        history.insert(host, at: 0)
        shared.setValue(history, forKey: kHistoryKey)
        shared.synchronize()
    }

    static func delete(host: String) {
        var history = shared.stringArray(forKey: kHistoryKey) ?? [String]()
        if let index = history.index(of: host) {
            history.remove(at: index)
            shared.setValue(history, forKey: kHistoryKey)
            shared.synchronize()
        }
    }
}
