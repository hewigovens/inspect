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
        guard let vc = board.instantiateViewController(withIdentifier: "ActionViewController") as? ActionViewController else {return nil}
        vc.URL = url
        return vc
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
                alert.addAction((UIAlertAction(title: "Rate us", style: .default, handler: { (action) -> Void in
                    self.extensionOpenUrl(kAppStoreHTTPUrl)
                })))
                alert.popoverPresentationController?.sourceView = self.view
                alert.popoverPresentationController?.sourceRect = self.view.frame
                self.present(alert, animated: true, completion: nil)
                defaults.set(true, forKey: kRatingKey)
            }
        }
        defaults.set(stats, forKey: kStatisticsKey)

        guard let shared = UserDefaults.init(suiteName: kInspectGroupId) else {
            return
        }
        var history = shared.stringArray(forKey: kHistoryKey) ?? [String]()

        if let index = history.index(of: host) {
            history.remove(at: index)
        }
        history.insert(host, at: 0)
        if history.count > 5 {
            history.remove(at: 5)
        }
        shared.setValue(history, forKey: kHistoryKey)
        shared.synchronize()
    }

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

        guard let path1 = bundle.path(forResource: "mozilla_trust", ofType: "json"),
              let path2 = bundle.path(forResource: "mozilla_ev", ofType: "json") else {
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
