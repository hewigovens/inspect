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

    @IBOutlet weak var imageView: UIImageView!
    private lazy var tableView = UITableView(frame: CGRectZero, style: .Plain);
    private var urlSession: NSURLSession?
    private var certificates: [SecCertificate] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for item: AnyObject in self.extensionContext!.inputItems {
            let inputItem = item as! NSExtensionItem
            for provider: AnyObject in inputItem.attachments! {
                let itemProvider = provider as! NSItemProvider
                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                    itemProvider.loadItemForTypeIdentifier(kUTTypeURL as String, options: nil, completionHandler: { (item, error) -> Void in
                        if let url = item as? NSURL?{
                            print("get url \(url), scheme = \(url?.scheme)");
                            if url?.scheme == ("https") {
                                self.urlSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: NSOperationQueue.mainQueue())
                                let task = self.urlSession?.dataTaskWithURL(url!)
                                if task != nil {
                                    task!.resume();
                                } else {
                                    self.showError();
                                }
                            }
                        }
                    });
                }
            }
        }
    }

    // MARK: Action
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func done() {
        self.extensionContext!.completeRequestReturningItems(self.extensionContext!.inputItems, completionHandler: nil)
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
        self.configTableView()
        completionHandler(.UseCredential, challenge.proposedCredential);
    }
    
    
    private func configTableView() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }
    
    private func showError() {
        
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
