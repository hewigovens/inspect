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
    case feedback
    case misc

    enum Item: String {
        case tutorial = "Tutorial"
        case feedback = "Send Feedback"
        case rateUs = "Rate on App Store"
        case about = "About"
        case ack = "Acknowledgements"
        case donate = "Donation"

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
            case .donate:
                return FAKIonIcons.image(with: "ion-social-bitcoin-outline")
            }
        }
    }

    var sections: [Item] {
        switch self {
        case .tutorial: return [Item.tutorial]
        case .feedback: return [Item.feedback, Item.donate, Item.rateUs]
        case .misc: return [Item.ack, Item.about]
        }
    }
}
