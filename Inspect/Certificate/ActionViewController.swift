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
                            UIActionSheetDelegate {
    
    @IBOutlet internal weak var navItem: UINavigationItem!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var headerTableView: UITableView!
    @IBOutlet weak var contentTableView: UITableView!
    @IBOutlet weak var headerHeightConstraint: NSLayoutConstraint!
    
    private var contentSections: [[String: AnyObject]]?
    private var contentSectionNames: [CertificateInfoSection]?
    private var inspectingUrl: NSURL?
    private var selectedCertInfo: [[String: String]] = []
    private var x509Certs: [X509Certificate] = []
    private var certificates: [SecCertificate] = [] {
        didSet {
            self.x509Certs = self.certificates.map({ (certificate) -> X509Certificate in
                return X509Certificate(certificate: certificate)
            })
            self.headerHeightConstraint.constant = CGFloat(48 * self.certificates.count)
            self.headerTableView.reloadData()
        }
    }
    private var selectedIndex: Int? {
        didSet {
            let tuples = self.x509Certs[self.selectedIndex!].displaySections()
            self.contentSections = tuples.0
            self.contentSectionNames = tuples.1
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
                    SessionManager.sharedManager.fetchCertsForUrl(url!, completion: { (certs) -> Void in
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
                            self.showError(error)
                        }
                    }
                    
                } else {
                    self.showError("not https url")
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
            let data = SecCertificateCopyData(cert) as NSData
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
            
            guard self.x509Certs.count > 0 else {
                return cell!
            }
            
            let sections = self.contentSections!
            let section = sections[indexPath.section]
            let keys = Array(section.keys)
            let key = keys[indexPath.row]
            let value = (section as NSDictionary).valueForKey(key) as! String
            cell?.titleLabel?.text = key
            cell?.detailLabel?.text = value
            return cell!
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
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
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
}
