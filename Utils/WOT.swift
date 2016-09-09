//
//  WOT.swift
//  Inspect
//
//  Created by hewig on 12/28/15.
//  Copyright © 2015 fourplex. All rights reserved.
//

import Foundation

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
    case success(Record)
    case failure(NSError)
}

public struct WOTRecord {
    let trustness: [Int]
    let target: String
    let categories: [String: Int]

    public init?(json: [String: AnyObject]) {

        guard let trustness = json["0"] as? [Int] else { return nil }
        self.trustness = trustness
        guard let target = json["target"] as? String else { return nil }
        self.target = target
        guard let categories = json["categories"] as? [String: Int] else { return nil }
        self.categories = categories
    }

    public func convertToRecord() -> Record {
        return Record(target: self.target, score: self.trustness[0], code: 300)
    }
}

open class WOT: NSObject {

    static func query(_ host: String, completion: @escaping (QueryResult) -> Void) -> Void {
        let key = "e0d9e530f85c4c851e2638b898d4219321c01455"
        let apiUrl = "http://api.mywot.com/0.4/public_link_json2"
        let query = "\(apiUrl)?key=\(key)&hosts=\(String(format: "%@/", host))"
        let request = URLRequest(url: URL(string: query)!)

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(QueryResult.failure(error as NSError))
                return
            }

            guard let data = data else { return }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                    as? [String: AnyObject] else { return }
                guard let target = json[host] as? [String: AnyObject] else { return }
                guard let wot = WOTRecord(json: target) else { return }
                completion(QueryResult.success(wot.convertToRecord()))
            } catch {}

        }
        task.resume()
    }
}
