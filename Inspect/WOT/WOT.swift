//
//  WOT.swift
//  Inspect
//
//  Created by hewig on 12/28/15.
//  Copyright © 2015 fourplex. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

public struct Record {
    public enum Reputation: String {
        case Excellent
        case Good
        case Unsatisfactory
        case Poor
        case VeryPoor
    }
    
    public enum Category {
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

public class WOT: NSObject {
    
    static func query(host: String, completion:(QueryResult) -> Void) -> Void {
        let key = "e0d9e530f85c4c851e2638b898d4219321c01455"
        let apiUrl = "http://api.mywot.com/0.4/public_link_json2"
        let parameters = [
            "hosts": String(format: "%@/", host),
            "key": key
        ];
        Alamofire.request(.GET, apiUrl, parameters: parameters).responseJSON { response in
            switch response.result {
            case .Success:
              if let value = response.result.value {
                let json = JSON(value)
                // todo category check
                let array = json[host]["0"].array;
                if let score = array?.first?.int {
                  let record = Record(target: host, score: score, code: 300)
                  completion(QueryResult.Success(record))
                }
              }
            case .Failure(let error):
                completion(QueryResult.Failure(error))
                print(error)
            }
        }
    }
}