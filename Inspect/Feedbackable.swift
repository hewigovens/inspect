//
//  Feedbackable.swift
//  Inspect
//
//  Created by hewig on 5/8/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit
import MessageUI

protocol Feedbackable: MFMailComposeViewControllerDelegate {
    func feedbackWithEmail()
}

extension UIViewController: Feedbackable {

    func feedbackWithEmail() {
        let controller = MFMailComposeViewController()
        controller.setToRecipients(["support@fourplex.in"])
        controller.setSubject("Inspect Feedback")
        controller.mailComposeDelegate = self
        self.presentViewController(controller, animated: true, completion: nil)
    }

    // MARK: MFMailComposeViewControllerDelegate
    public func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}
