//
//  ActionViewController+Utils.swift
//  Inspect
//
//  Created by hewig on 9/9/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit

extension ActionViewController {

    class func create(url: URL) -> ActionViewController? {
        let board = UIStoryboard(name: "MainInterface", bundle: Bundle.main)
        guard let controller = board.instantiateViewController(withIdentifier: "ActionViewController") as? ActionViewController else {return nil}
        controller.URL = url
        return controller
    }

    internal func updateStatistics(_ host: String) {
        let defaults = UserDefaults.standard
        #if DEBUG
            defaults.set(false, forKey: kRatingKey)
        #endif
        var stats = defaults.integer(forKey: kStatisticsKey)
        stats += 1
        if self.inExtensionContext && !defaults.bool(forKey: kRatingKey) {
            if stats >= 5 {
                let alert = UIAlertController(title: "Hooray", message: "You have inspected \(stats) sites. :)", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Next Time", style: .default, handler: nil))
                alert.addAction((UIAlertAction(title: "Rate us", style: .default, handler: { _ in
                    self.extensionOpenUrl(kAppStoreHTTPUrl)
                })))
                alert.popoverPresentationController?.sourceView = self.view
                alert.popoverPresentationController?.sourceRect = self.view.frame
                self.present(alert, animated: true, completion: nil)
                defaults.set(true, forKey: kRatingKey)
            }
        }
        defaults.set(stats, forKey: kStatisticsKey)

        UserDefaults.add(host: host)
    }

    internal func extensionOpenUrl(_ urlString: String) {

        guard let url = Foundation.URL(string: urlString) else {return}

        if let action = self.openURLAction {
            action(url)
            return
        }

        var responder = self as UIResponder?
        while let res = responder {
            let sel = NSSelectorFromString("openURL:")
            if res.responds(to: sel) {
                res.perform(sel, with: url)
            }
            responder = res.next
        }
    }

    internal func loadRootCAs() {

        var bundle: Bundle = Bundle.main

        if self.inExtensionContext {
            var url = bundle.bundleURL.deletingLastPathComponent()
            url = url.deletingLastPathComponent()
            guard let extBundle = Bundle(url: url) else {
                return
            }
            bundle = extBundle
        }

        guard let path1 = bundle.path(forResource: "mozilla_trust", ofType: "json") else {
            return
        }
        guard let path2 = bundle.path(forResource: "mozilla_ev", ofType: "json") else {
            return
        }
        do {
            guard let data1 = try? Data(contentsOf: Foundation.URL(fileURLWithPath: path1)), let data2 = try? Data(contentsOf: Foundation.URL(fileURLWithPath: path2))
                else {
                return
            }
            self.rootCAs = try JSONSerialization.jsonObject(with: data1, options: .allowFragments) as? [String: AnyObject]
            self.evSet = try JSONSerialization.jsonObject(with: data2, options: .allowFragments) as? [String: AnyObject]
        } catch let error {
            debugPrint(error)
        }
    }
}
