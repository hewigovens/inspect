//
//  Constants.swift
//  Inspect
//
//  Created by hewigovens on 1/21/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import Foundation

let kHockeyAppId = "399c05d7126848fabac6f9e2341880f8"
let kAppStoreUrl = "itms://itunes.apple.com/us/app/inspect-safari-extension-to/id1074957486?ls=1&mt=8"
let kAppStoreHTTPUrl = "https://itunes.apple.com/us/app/inspect-safari-extension-to/id1074957486?ls=1&mt=8"
let kRatingKey = "Rating"
let kStatisticsKey = "Statistics"
let kFirstRun = "FirstRun"

func AppStoreURLs() -> [NSURL] {
    var urls = [NSURL]()
    if let url = NSURL(string: kAppStoreUrl) {
        urls.append(url)
    }
    if let url = NSURL(string: kAppStoreHTTPUrl) {
        urls.append(url)
    }
    return urls
}
