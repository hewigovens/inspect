//
//  ActionViewController+Utils.swift
//  Inspect
//
//  Created by hewig on 9/9/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit

extension ActionViewController {
    internal func extensionOpenUrl(_ urlString: String) {

        guard let url = Foundation.URL(string: urlString) else {return}

        if let action = self.openURLAction {
            action(url)
            return
        }

        var responder = self as UIResponder?
        while let r = responder {
            let sel = NSSelectorFromString("openURL:")
            if r.responds(to: sel) {
                r.perform(sel, with: url)
            }
            responder = r.next
        }
    }

    internal func loadRootCAs() {

        var bundle: Bundle = Bundle.main

        if self.inExtensionContext {
            let url = bundle.bundleURL.deletingLastPathComponent()
            guard let _bundle = Bundle(url: url) else {
                return
            }
            bundle = _bundle
        }

        guard let path = bundle.path(forResource: "mozilla_trust", ofType: "json") else {
            return
        }
        do {
            guard let data = try? Data(contentsOf: Foundation.URL(fileURLWithPath: path)) else {
                return
            }
            self.rootCAs = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: AnyObject]

        } catch let error {
            debugPrint(error)
        }
    }
}
