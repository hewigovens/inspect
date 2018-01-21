//
//  HomeSection.swift
//  Inspect
//
//  Created by Tao Xu on 10/7/17.
//  Copyright © 2017 fourplex. All rights reserved.
//

import UIKit
import FontAwesomeKit

enum HomeSection: Int {
    case tutorial
    case setting
    case feedback
    case misc

    enum Item: String {
        case tutorial = "Tutorial"
        case feedback = "Send Feedback"
        case mitm = "Enable MITM Detection"
        case rateUs = "Rate on App Store"
        case about = "About"
        case ack = "Acknowledgements"

        var image: UIImage? {
            switch self {
            case .tutorial:
                return FAKIonIcons.image(with: "ion-ios-lightbulb-outline")
            case .feedback:
                return FAKIonIcons.image(with: "ion-ios-email-outline")
            case .about:
                return FAKIonIcons.image(with: "ion-ios-information-outline")
            case .rateUs:
                return FAKIonIcons.image(with: "ion-ios-heart-outline")
            case .ack:
                return FAKIonIcons.image(with: "ion-social-github-outline")
            case .mitm:
                return FAKIonIcons.image(with: "ion-ios-toggle-outline")
            }
        }
    }

    var sections: [Item] {
        switch self {
        case .tutorial: return [Item.tutorial]
        case .setting: return [Item.mitm]
        case .feedback: return [Item.feedback, Item.rateUs]
        case .misc: return [Item.ack, Item.about]
        }
    }
}
