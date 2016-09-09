//
//  AppDelegate.swift
//  Inspect
//
//  Created by hewig on 12/28/15.
//  Copyright © 2015 fourplex. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        UserDefaults.standard.register(
            defaults: [kFirstRun: true]
        )

        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = UINavigationController(rootViewController: HomeViewController())
        self.window?.makeKeyAndVisible()

        Fabric.with([Answers.self, Crashlytics.self])
        self.inspectURL(URL(string: "https://www.apple.com")!)
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        if UserDefaults.standard.bool(forKey: kFirstRun) {
            return
        }
        guard let pasted = UIPasteboard.general.string else {return}
        guard let url = URL(string: pasted) , url.scheme == "https" else {return}
        self.inspectURL(url)
    }

    fileprivate func inspectURL(_ url: URL) {

        let presentedViewController = self.window?.rootViewController?.presentedViewController
        if presentedViewController is ActionViewController ||
            presentedViewController is TutorialViewController {
            return
        }

        let alert = UIAlertController(title: "Aha", message: "Do you want to Inspect \(url.absoluteString) ?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Next Time", style: .default, handler: { _ in
            UIPasteboard.general.string = ""
        }))
        alert.addAction(UIAlertAction(title: "Sure", style: .default, handler: { _ in
            let board = UIStoryboard(name: "MainInterface", bundle: Bundle.main)
            guard let vc = board.instantiateViewController(withIdentifier: "ActionViewController") as? ActionViewController else {return}
            vc.URL = url
            vc.openURLAction = { url in
                if UIApplication.shared.canOpenURL(url as URL) {
                    UIApplication.shared.openURL(url as URL)
                }
            }
            UIPasteboard.general.string = ""
            DispatchQueue.main.async(execute: {
                self.window?.rootViewController!.present(vc, animated: true, completion: nil)
            })
        }))
        self.window?.rootViewController!.present(alert, animated: true, completion: nil)
    }
}
