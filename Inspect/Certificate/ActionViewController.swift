//
//  ActionViewController.swift
//  Certificate
//
//  Created by hewig on 12/28/15.
//  Copyright © 2015 fourplex. All rights reserved.
//

import UIKit
import MobileCoreServices


class ActionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSURLSessionDelegate {
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var headerTableView: UITableView!
    @IBOutlet weak var contentTableView: UITableView!
    private var urlSession: NSURLSession?
    private var certificates: [SecCertificate] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Inspect - Certificate"
        
        var validItemProvider: NSItemProvider?
        nestedLoop: for item: AnyObject in self.extensionContext!.inputItems {
            let inputItem = item as! NSExtensionItem
            for provider: AnyObject in inputItem.attachments! {
                let itemProvider = provider as! NSItemProvider
                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                    validItemProvider = itemProvider
                    break nestedLoop
                }
            }
        }
        
        if validItemProvider != nil {
            validItemProvider!.loadItemForTypeIdentifier(kUTTypeURL as String, options: nil, completionHandler: { (item, error) -> Void in
                if let url = item as? NSURL? {
                    print("get url \(url), scheme = \(url?.scheme)");
                    if url?.scheme == ("https") {
                        self.urlSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: NSOperationQueue.mainQueue())
                        let task = self.urlSession?.dataTaskWithURL(url!)
                        if task != nil {
                            task!.resume();
                            if let host = url?.host {
                                WOT.query(host) { result in
                                    print(result)
                                    switch result {
                                    case .Success(let record):
                                        self.showWOTRating(record)
                                    case .Failure(let error):
                                        self.showError(error)
                                    }
                                }
                            }
                        }
                    } else {
                        self.showError("not https url")
                    }
                } else {
                    self.showError("url is not valid NSURL object")
                }
            });
        } else {
            self.showError("no valid item privoder!")
        }
    }
    
    // MARK: Action
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func done() {
        self.extensionContext!.completeRequestReturningItems(self.extensionContext!.inputItems, completionHandler: nil)
    }
    
    @IBAction func share() {
        let activity = UIActivityViewController(activityItems: [], applicationActivities: nil)
        self.presentViewController(activity, animated: true) { () -> Void in
            //
        }
    }
    
    // MARK: UITableViewDelegate
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        return UITableViewCell()
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return certificates.count
    }
    
    
    // MARK: NSURLSessionDelegate
    
    func URLSession(session: NSURLSession, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
        
        self.certificates = self.certificateDataForTrust(challenge.protectionSpace.serverTrust!)
        completionHandler(.UseCredential, challenge.proposedCredential);
    }
    
    // MARK: Private funcs
    private func showWOTRating(record: Record) {
        
    }
    
    private func showError(errorMessage: String) {
        print("error \(errorMessage)")
    }
    
    private func showError(error: NSError) {
        print("error \(error.description)")
    }
    
    private func certificateDataForTrust(trust: SecTrust) -> [SecCertificate] {
        var certs: [SecCertificate] = []
        for index in 0..<SecTrustGetCertificateCount(trust) {
            if let cert = SecTrustGetCertificateAtIndex(trust, index) {
                certs.append(cert)
            }
        }
        return certs;
    }
}
