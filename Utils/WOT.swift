//
//  WOT.swift
//  Inspect
//
//  Created by hewig on 12/28/15.
//  Copyright © 2015 fourplex. All rights reserved.
//

import Foundation
import Unbox

public struct Record {
    public enum Reputation: String {
        case Excellent
        case Good
        case Unsatisfactory
        case Poor
        case VeryPoor
    }

    public enum Category: String {
        case Negative
        case Questionable
        case Neutral
        case Positive
    }

    var target: String
    var score: Int
    var code: Int
    
    var reputation: Reputation {
        get {
            if self.score >= 80 {
                return .Excellent
            } else if self.score >= 60 {
                return .Good
            } else if self.score >= 40 {
                return .Unsatisfactory
            } else if self.score >= 20 {
                return .Poor
            } else {
                return .VeryPoor
            }
        }
    }
    var category: Category {
        get {
            if self.code >= 500 {
                return .Positive
            } else if self.code >= 300 {
                return .Neutral
            } else if self.code >= 200 {
                return .Questionable
            } else {
                return .Negative
            }
        }
    }
}

public enum QueryResult {
    case Success(Record)
    case Failure(NSError)
}

struct WOTRecord: Unboxable {
    let trustness: [Int]
    let target: String
    let categories: [String: Int]

    init(unboxer: Unboxer) {
        self.trustness = unboxer.unbox("0")
        self.target = unboxer.unbox("target")
        self.categories = unboxer.unbox("categories")
    }

    func convertToRecord() -> Record {
        return Record(target: self.target, score: self.trustness[0], code: 300)
    }
}

public class WOT: NSObject {

    static func query(host: String, completion: (QueryResult) -> Void) -> Void {
        let key = "e0d9e530f85c4c851e2638b898d4219321c01455"
        let apiUrl = "http://api.mywot.com/0.4/public_link_json2"
        let query = "\(apiUrl)?key=\(key)&hosts=\(String(format: "%@/", host))"
        let request = NSMutableURLRequest(URL: NSURL(string: query)!)
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error in
            if let error = error {
                completion(QueryResult.Failure(error))
                return
            }

            guard let data = data else {
                return
            }
            do {
                guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String: AnyObject]    else {
                    return
                }

                guard let target = json[host] as? [String: AnyObject] else {
                    return
                }

                if let wot: WOTRecord? = Unbox(target) {
                    if let wot = wot {
                        completion(QueryResult.Success(wot.convertToRecord()))
                    }
                }
            } catch {
            }
        }
        task.resume()
    }
}
