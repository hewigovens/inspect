//
//  ActionViewController+Utils.swift
//  Inspect
//
//  Created by hewig on 9/9/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit

extension ActionViewController {
    internal func extensionOpenUrl(urlString: String) {

        guard let url = NSURL(string: urlString) else {return}

        if let action = self.openURLAction {
            action(url)
            return
        }

        var responder = self as UIResponder?
        while let r = responder {
            let sel = NSSelectorFromString("openURL:")
            if r.respondsToSelector(sel) {
                r.performSelector(sel, withObject: url)
            }
            responder = r.nextResponder()
        }
    }

    internal func loadRootCAs() {

        var bundle: NSBundle = NSBundle.mainBundle()

        if self.inExtensionContext {
            let url = bundle.bundleURL.URLByDeletingLastPathComponent
            guard let _url = url?.URLByDeletingLastPathComponent else {
                return
            }
            guard let _bundle = NSBundle(URL: _url) else {
                return
            }
            bundle = _bundle
        }

        guard let path = bundle.pathForResource("mozilla_trust", ofType: "json") else {
            return
        }
        do {
            guard let data = NSData(contentsOfFile: path) else {
                return
            }
            self.rootCAs = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String: AnyObject]

        } catch let error {
            debugPrint(error)
        }
    }
}
