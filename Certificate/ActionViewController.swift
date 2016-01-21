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
import HockeySDK
import MessageUI

class ActionViewController: UIViewController,
                            UITableViewDelegate,
                            UITableViewDataSource,
                            UIActionSheetDelegate,
                            MFMailComposeViewControllerDelegate {
    
    @IBOutlet internal weak var navItem: UINavigationItem!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var headerTableView: UITableView!
    @IBOutlet weak var contentTableView: UITableView!
    @IBOutlet weak var headerHeightConstraint: NSLayoutConstraint!
    
    private var didSetupHockeySDK = false
    private var contentSections: [[(String, AnyObject)]]?
    private var contentSectionNames: [CertificateInfoSection]?
    private var inspectingUrl: NSURL?
    private var selectedCertInfo: [[String: String]] = []
    private var x509Certs: [X509Certificate] = []
    private var certificates: [(SecCertificate, SecTrustResultType)] = [] {
        didSet {
            self.x509Certs = self.certificates.map({ (certificate) -> X509Certificate in
                return X509Certificate(certificate: certificate.0)
            })
            self.headerTableView.hidden = false
            self.contentTableView.hidden = false
            self.headerHeightConstraint.constant = CGFloat(48 * self.certificates.count)
            self.headerTableView.reloadData()
        }
    }
    private var selectedIndex: Int? {
        didSet {
            let cert = self.x509Certs[self.selectedIndex!]
            let tuples = cert.displaySections()
            self.contentSections = tuples.0
            self.contentSectionNames = tuples.1
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if !self.didSetupHockeySDK {
            BITHockeyManager.sharedHockeyManager().configureWithIdentifier(kHockeyAppId)
            BITHockeyManager.sharedHockeyManager().startManager()
            self.didSetupHockeySDK = true
        }
        
        self.navItem?.title = "Inspect - Certificate"
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
        guard validItemProvider != nil else { return self.showError("no valid item privoder!") }
        
        self.configureTableViews()
        validItemProvider!.loadItemForTypeIdentifier(kUTTypeURL as String, options: nil, completionHandler: { (item, error) -> Void in
            if let url = item as? NSURL? {
                self.inspectingUrl = url
                print("get url \(url), scheme = \(url?.scheme)");
                if url?.scheme == ("https") {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        INHUD.sharedHUD.contentView = INHUDTextView(text: "Fetching Certificates…")
                        INHUD.sharedHUD.showInView(self.view)
                    })
                    SessionManager.sharedManager.fetchCertsForUrl(url!, completion: { (certs) -> Void in
                        INHUD.sharedHUD.hide()
                        if certs.count > 0 {
                            self.certificates = certs
                            self.selectedIndex = certs.count - 1
                        }
                    })
                    WOT.query((url?.host)!) { result in
                        print(result)
                        switch result {
                        case .Success(let record):
                            self.showWOTRating(record)
                        case .Failure(let error):
                            #if DEBUG
                            self.showError(error)
                            #endif
                        }
                    }
                    
                } else {
                    self.showError("\(url!) seems not a https URL")
                }
            } else {
                self.showError("url is not valid NSURL object")
            }
        });
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
        
        sheet.addAction(UIAlertAction(title: "Export Certificate", style: .Default, handler: { (action) -> Void in
            
            if self.selectedIndex == nil {
                self.selectedIndex = self.certificates.count - 1;
            }
            let cert = self.certificates[self.selectedIndex!]
            let data = SecCertificateCopyData(cert.0) as NSData
            let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
            if let path = paths.first {
                let file_name = "cert\(self.selectedIndex!).cer";
                let file_zip_name = "/cert\(self.selectedIndex!).zip"
                let cert_zip = NSURL(fileURLWithPath: path + file_zip_name);
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
        
        sheet.addAction(UIAlertAction(title: "Feedback", style: .Default, handler: { (action) -> Void in
            let controller = MFMailComposeViewController()
            controller.setToRecipients(["support@fourplex.in"])
            controller.setSubject("Inspect Feedback")
            controller.mailComposeDelegate = self
            self.presentViewController(controller, animated: true, completion: nil)
        }))
        
        sheet.addAction(UIAlertAction(title: "Helpful? Rate US", style: .Default, handler: { (action) -> Void in
           self.extensionContext?.openURL(NSURL(string: kAppStoreUrl)!, completionHandler: nil)
        }))
        
        sheet.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        
        self.presentViewController(sheet, animated: true, completion: nil)
    }
    
    // MARK: UITableViewDelegate
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if tableView == self.headerTableView {
            let cert = self.certificates[indexPath.row]
            let cell = tableView.dequeueReusableCellWithIdentifier(CertificateStackCell.reuseId) as? CertificateStackCell
            cell?.trustResult = cert.1
            cell?.level = indexPath.row
            cell?.name = SecCertificateCopySubjectSummary(cert.0) as String
            return cell!
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier(CertificateInfoCell.reuseId) as? CertificateInfoCell
            
            guard self.x509Certs.count > 0 else {
                return cell!
            }
            
            let sections = self.contentSections!
            let section = sections[indexPath.section]
            let tuple = section[indexPath.row]
            let sectionType = self.contentSectionNames![indexPath.section]
            if sectionType == .PubKeyInfo ||
                sectionType == .Fingerprints ||
                sectionType == .Signature ||
                sectionType == .Extensions {
                let cell2 = tableView.dequeueReusableCellWithIdentifier(CertificateInfoCell2.reuseId) as? CertificateInfoCell2
                cell2?.titleLabel?.text = tuple.0
                cell2?.longTextLabel?.text = tuple.1 as? String
                if sectionType != .Extensions {
                    cell2?.longTextLabel.font = UIFont(name: "Courier", size: 15)
                } else {
                    cell2?.longTextLabel.font = UIFont.systemFontOfSize(15)
                }
                return cell2!
            } else {
                cell?.titleLabel?.text = tuple.0
                cell?.detailLabel?.text = tuple.1 as? String
                return cell!
            }
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if tableView == self.headerTableView {
            return 1
        } else {
            return self.contentSectionNames?.count ?? 0
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.headerTableView {
            return certificates.count
        } else {
            if let sections = self.contentSections {
                return sections[section].count
            }
            return 0
        }
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if tableView == self.contentTableView {
            return self.contentSectionNames?[section].rawValue ?? nil
        }
        return nil
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if tableView == self.headerTableView {
            self.selectedIndex = indexPath.row
            self.contentTableView.reloadData()
        } else {
            let sections = self.contentSections!
            let section = sections[indexPath.section]
            let tuple = section[indexPath.row]
            UIPasteboard.generalPasteboard().setValue(tuple.1, forPasteboardType: kUTTypePlainText as String)
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
    }
    
    // MARK: MFMailComposeViewControllerDelegate
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: Private funcs
    
    private func configureTableViews() {
        
        // Certificate Stack View
        self.headerTableView.bounces = false
        self.headerTableView.separatorStyle = .None
        self.headerTableView.rowHeight = UITableViewAutomaticDimension
        self.headerTableView.estimatedRowHeight = 44
        self.headerTableView.backgroundColor = UIColor.lightTextColor()
        self.headerTableView.hidden = true
        
        self.contentTableView.estimatedRowHeight = 100
        self.contentTableView.rowHeight = UITableViewAutomaticDimension
        self.contentTableView.hidden = true
    }
    
    private func showWOTRating(record: Record) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.navItem?.titleView = self.genTitleView(record)
        }
    }
    
    private func showError(errorMessage: String) {
        print("error \(errorMessage)")
        
        let alert = UIAlertController(title: "Error", message: errorMessage, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    private func showError(error: NSError) {
        return self.showError(error.description)
    }
    
    private func genTitleView(record: Record) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = UIColor.clearColor()
        let string = NSMutableAttributedString(string: "WOT: \(record.reputation.rawValue) ", attributes: [NSFontAttributeName: UIFont.systemFontOfSize(17)])
        let attachment = NSTextAttachment()
        attachment.image = UIImage(named: "WOT\(record.reputation.rawValue)")
        attachment.bounds = CGRectMake(4, -4, 20, 20)
        string.appendAttributedString(NSAttributedString(attachment: attachment))
        textView.attributedText = string
        textView.sizeToFit()
        return textView
    }
}
