//
//  Feedbackable.swift
//  Inspect
//
//  Created by hewig on 5/8/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit
import MessageUI

let kFeedbackRecipient = "support@fourplex.in"
let kFeedbackSubject = "Inspect Feedback"

protocol Feedbackable: MFMailComposeViewControllerDelegate {
    func feedbackCanSendMail() -> Bool
    func feedbackMailToString() -> String
    func feedbackWithEmail()
}

extension UIViewController: Feedbackable {

    func feedbackCanSendMail() -> Bool {
        return MFMailComposeViewController.canSendMail()
    }

    func feedbackMailToString() -> String {
        if let mailTo = "mailto:\(kFeedbackRecipient)?subject=\(kFeedbackSubject)"
            .stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet()) {
            return mailTo
        } else {
            return ""
        }
    }

    func feedbackWithEmail() {
        guard MFMailComposeViewController.canSendMail() else {
            return
        }
        let controller = MFMailComposeViewController()
        controller.setToRecipients([kFeedbackRecipient])
        controller.setSubject(kFeedbackSubject)
        controller.mailComposeDelegate = self
        self.presentViewController(controller, animated: true, completion: nil)
    }

    // MARK: MFMailComposeViewControllerDelegate
    public func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}
