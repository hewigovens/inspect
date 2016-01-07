//
//  ActionViewController.swift
//  Certificate
//
//  Created by hewig on 12/28/15.
//  Copyright © 2015 fourplex. All rights reserved.
//

import UIKit
import MobileCoreServices
import SafariServices

class ActionViewController: UIViewController,
                            UITableViewDelegate,
                            UITableViewDataSource,
                            NSURLSessionDelegate,
                            UIActionSheetDelegate {
    
    @IBOutlet internal weak var navItem: UINavigationItem!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var headerTableView: UITableView!
    @IBOutlet weak var contentTableView: UITableView!
    @IBOutlet weak var headerHeightConstraint: NSLayoutConstraint!
    
    private var selectedIndex: Int? {
        didSet {
            self.selectedCert = X509Certificate(certificate: certificates[self.selectedIndex!])
        }
    }
    private var selectedCert: X509Certificate?
    private var inspectingUrl: NSURL?
    private var urlSession: NSURLSession?
    private lazy var requestQueue = NSOperationQueue()
    private var certificates: [SecCertificate] = [] {
        didSet {
            self.headerHeightConstraint.constant = CGFloat(50 * self.certificates.count)
            self.headerTableView.reloadData()
        }
    }
    private var selectedCertInfo: [[String: String]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navItem?.title = "Inspect - Certificate"
        self.configureTableViews()
        
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
                    self.inspectingUrl = url
                    print("get url \(url), scheme = \(url?.scheme)");
                    if url?.scheme == ("https") {
                        self.urlSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: self.requestQueue)
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
        let sheet = UIAlertController(title: "More Options", message: nil, preferredStyle: .ActionSheet)
        sheet.addAction(UIAlertAction(title: "Scan in SSLLabs.com", style: .Default, handler: { (action) -> Void in
            if self.inspectingUrl != nil {
            if let url = SSLLabs.scanUrl((self.inspectingUrl?.host)!) {
                    let vc = SFSafariViewController(URL: url)
                    self.presentViewController(vc, animated: true, completion: nil)
                }
            }
        }))
        
        sheet.addAction(UIAlertAction(title: "Export Certificates", style: .Default, handler: { (action) -> Void in
            
            if self.selectedIndex == nil {
                self.selectedIndex = self.certificates.count - 1;
            }
            let cert = self.certificates[self.selectedIndex!]
            let data = SecCertificateCopyData(cert) as NSData
            let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
            if let path = paths.first {
                let file_name = "cert0.cer";
                let cert_zip = NSURL(fileURLWithPath: path + "/cert0.zip");
                print(cert_zip)
                do {
                    let archive = try ZZArchive(URL: cert_zip, options: [ZZOpenOptionsCreateIfMissingKey: NSNumber(bool: true)])
                    let entry = ZZArchiveEntry(fileName: file_name, compress: true, dataBlock: { (_) -> NSData? in
                        return data;
                    })
                    try archive.updateEntries([entry])
                    
                    let items = [cert_zip]
                    let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
                    self.presentViewController(vc, animated: true, completion: nil)
                    
                } catch (let error as NSError) {
                    print("zip cert failed \(error.description)")
                }
            }
        }))
        
        sheet.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        
        self.presentViewController(sheet, animated: true, completion: nil)
    }
    
    // MARK: UITableViewDelegate
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if tableView == self.headerTableView {
            let cert = self.certificates[indexPath.row]
            let cell = tableView.dequeueReusableCellWithIdentifier(CertificateStackCell.reuseId) as? CertificateStackCell
            cell?.level = indexPath.row
            cell?.name = SecCertificateCopySubjectSummary(cert) as String
            return cell!
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier(CertificateInfoCell.reuseId) as? CertificateInfoCell
            cell?.titleLabel?.text = "This is key"
            cell?.detailLabel?.text = "This is very long text.This is very long text.This is very long text.This is very long text.This is very long text.This is very long text."
            return cell!
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if tableView == self.headerTableView {
            return 1;
        } else {
            return 7;
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.headerTableView {
            return certificates.count
        } else {
            return 2
        }
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if tableView == self.contentTableView {
            return "Section Header"
        }
        return nil
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if tableView == self.headerTableView {
            self.selectedIndex = indexPath.row
            self.contentTableView.reloadData()
        }
    }
    
    // MARK: NSURLSessionDelegate
    
    func URLSession(session: NSURLSession, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.certificates = self.certificateDataForTrust(challenge.protectionSpace.serverTrust!)
            if self.certificates.count > 0 {
                self.selectedIndex = self.certificates.count - 1
            }
        }
        completionHandler(.CancelAuthenticationChallenge, challenge.proposedCredential);
    }
    
    // MARK: Private funcs
    
    private func configureTableViews() {
        
        // Certificate Stack View
        self.headerTableView.bounces = false
        self.headerTableView.separatorStyle = .None
        self.headerTableView.rowHeight = UITableViewAutomaticDimension
        self.headerTableView.estimatedRowHeight = 44
        self.headerTableView.backgroundColor = UIColor.lightTextColor()
        
        self.contentTableView.estimatedRowHeight = 100
        self.contentTableView.rowHeight = UITableViewAutomaticDimension
    }
    
    private func showWOTRating(record: Record) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.navItem?.title = "Web of Trust: \(record.reputation.rawValue)"
        }
    }
    
    private func showError(errorMessage: String) {
        print("error \(errorMessage)")
        self.navigationItem.rightBarButtonItem?.enabled = false
    }
    
    private func showError(error: NSError) {
        return self.showError(error.description)
    }
    
    private func certificateDataForTrust(trust: SecTrust) -> [SecCertificate] {
        var certs: [SecCertificate] = []
        for index in 0..<SecTrustGetCertificateCount(trust) {
            if let cert = SecTrustGetCertificateAtIndex(trust, index) {
                certs.append(cert)
            }
        }
        return certs.reverse();
    }
}
