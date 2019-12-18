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

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        UserDefaults.standard.register(
            defaults: [kFirstRun: true]
        )
        setupAppearance()

        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = UINavigationController(rootViewController: HomeViewController())
        self.window?.makeKeyAndVisible()

        Fabric.with([Answers.self, Crashlytics.self])
        return true
    }

    func setupAppearance() {
        if #available(iOS 11.0, *) {
            UINavigationBar.appearance().largeTitleTextAttributes =
                [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 24, weight: .light)]
        }
        UINavigationBar.appearance().barTintColor = UIColor.white
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .light)]
    }
}
