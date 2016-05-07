//
//  AppDelegate.swift
//  Inspect
//
//  Created by hewig on 12/28/15.
//  Copyright © 2015 fourplex. All rights reserved.
//

import UIKit
import HockeySDK
import Fabric
import Answers

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        NSUserDefaults.standardUserDefaults().registerDefaults(
            [kFirstRun: true]
        )

        self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
        self.window?.rootViewController = UINavigationController(rootViewController: HomeViewController())
        self.window?.makeKeyAndVisible()

        BITHockeyManager.sharedHockeyManager().configureWithIdentifier(kHockeyAppId)
        BITHockeyManager.sharedHockeyManager().startManager()
        BITHockeyManager.sharedHockeyManager().authenticator.authenticateInstallation()

        Fabric.with([Answers.self])

        return true
    }

    func applicationDidBecomeActive(application: UIApplication) {
        if NSUserDefaults.standardUserDefaults().boolForKey(kFirstRun) {
            return
        }
        guard let pasted = UIPasteboard.generalPasteboard().string else {return}
        guard let url = NSURL(string: pasted) where url.scheme == "https" else {return}
        self.inspectURL(url)
    }

    private func inspectURL(url: NSURL) {

        let presentedViewController = self.window?.rootViewController?.presentedViewController
        if presentedViewController is ActionViewController ||
            presentedViewController is TutorialViewController {
            return
        }

        let alert = UIAlertController(title: "Aha", message: "Do you want to Inspect \(url.absoluteString) ?", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Next Time", style: .Default, handler: nil))
        alert.addAction(UIAlertAction(title: "Sure", style: .Default, handler: { _ in
            let board = UIStoryboard(name: "MainInterface", bundle: NSBundle.mainBundle())
            guard let vc = board.instantiateViewControllerWithIdentifier("ActionViewController") as? ActionViewController else {return}
            vc.URL = url
            vc.openURLAction = { url in
                UIApplication.sharedApplication().openURL(url)
            }
            dispatch_async(dispatch_get_main_queue(), {
                self.window?.rootViewController!.presentViewController(vc, animated: true, completion: nil)
            })
        }))
        self.window?.rootViewController!.presentViewController(alert, animated: true, completion: nil)
    }
}
