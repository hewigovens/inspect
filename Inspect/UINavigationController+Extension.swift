//
//  UINavigationController+Extension.swift
//  Inspect
//
//  Created by hewig on 5/7/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit
extension UINavigationController {
    public func presentTransparentNavigationBar() {
        navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationBar.isTranslucent = true
        navigationBar.shadowImage = UIImage()
        setNavigationBarHidden(false, animated: true)
    }

    public func hideTransparentNavigationBar() {
        setNavigationBarHidden(true, animated: false)
        navigationBar.setBackgroundImage(UINavigationBar.appearance().backgroundImage(for: UIBarMetrics.default), for: UIBarMetrics.default)
        navigationBar.isTranslucent = UINavigationBar.appearance().isTranslucent
        navigationBar.shadowImage = UINavigationBar.appearance().shadowImage
    }
}

extension UIViewController {
    public func setLightStatusBar() {
        UIApplication.shared.statusBarStyle = .lightContent
    }

    public func setDarkStatusBar() {
        UIApplication.shared.statusBarStyle = .default
    }
}
