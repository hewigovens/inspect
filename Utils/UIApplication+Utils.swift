//
//  UIApplication+Utils.swift
//  Inspect
//
//  Created by hewig on 4/16/17.
//  Copyright © 2017 fourplex. All rights reserved.
//

import UIKit

extension UIApplication {
    struct fp {
        static func openURL(_ url: URL) -> Bool {
            guard UIApplication.shared.canOpenURL(url) else {
                return false
            }
            return UIApplication.shared.openURL(url)
        }
    }
}
