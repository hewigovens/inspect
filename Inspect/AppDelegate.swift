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
        
        BITHockeyManager.sharedHockeyManager().configureWithIdentifier(kHockeyAppId)
        BITHockeyManager.sharedHockeyManager().startManager()
        BITHockeyManager.sharedHockeyManager().authenticator.authenticateInstallation()
        
        Fabric.with([Answers.self])
        
        return true
    }
}

