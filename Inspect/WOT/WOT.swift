//
//  WOT.swift
//  Inspect
//
//  Created by hewig on 12/28/15.
//  Copyright © 2015 fourplex. All rights reserved.
//

import Foundation

public enum QueryResult {
    case Success
    case Failure(NSError)
}

public enum Reputation {
    case Excellent
    case Good
    case Unsatisfactory
    case Poor
    case VeryPoor
}

public enum Category {
    
}

public class WOT: NSObject {
    
    static let key = "e0d9e530f85c4c851e2638b898d4219321c01455"
    static let apiUrl = "http://api.mywot.com/0.4/public_link_json2"
    static func query(host: String, completion:(QueryResult)) -> Void {
        let queryUrl = String(format: "%s?host=%s/&key=%s", WOT.apiUrl, host, WOT.key)
        let task = NSURLSession.sharedSession().dataTaskWithURL(NSURL(string: queryUrl)!)
        task.resume()
    }
}