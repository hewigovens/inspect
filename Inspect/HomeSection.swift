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
    case tutorial = 0
    case misc = 1

    enum Item: String {
        case howToUseIt = "Tutorial"
        case feedback = "Send Feedback"
        case rateUs = "Rate on App Store"
        case about = "About"

        var image: UIImage? {
            switch self {
            case .howToUseIt:
                return FAKIonIcons.image(with: "ion-ios-lightbulb-outline")
            case .feedback:
                return FAKIonIcons.image(with: "ion-ios-email-outline")
            case .about:
                return FAKIonIcons.image(with: "ion-ios-information-outline")
            case .rateUs:
                return FAKIonIcons.image(with: "ion-ios-heart-outline")
            }
        }
    }

    var sections: [Item] {
        switch self {
        case .tutorial:return [Item.howToUseIt]
        case .misc: return [Item.feedback, Item.rateUs, Item.about]
        }
    }
}
