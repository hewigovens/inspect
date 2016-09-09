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

protocol Feedbackable {
    func feedbackCanSendMail() -> Bool
    func feedbackMailToString() -> String
    func feedbackWithEmail()
}

extension UIViewController: Feedbackable, MFMailComposeViewControllerDelegate {

    func feedbackCanSendMail() -> Bool {
        return MFMailComposeViewController.canSendMail()
    }

    func feedbackMailToString() -> String {
        if let mailTo = "mailto:\(kFeedbackRecipient)?subject=\(kFeedbackSubject)"
            .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) {
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
        self.present(controller, animated: true, completion: nil)
    }

    // MARK: MFMailComposeViewControllerDelegate
    @objc(mailComposeController:didFinishWithResult:error:)
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
}
