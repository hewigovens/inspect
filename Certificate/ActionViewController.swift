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
import StoreKit
import Crashlytics
import Fabric

class ActionViewController: UIViewController,
                            UITableViewDelegate,
                            UITableViewDataSource,
                            UIActionSheetDelegate {

    @IBOutlet internal weak var navItem: UINavigationItem!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var headerTableView: UITableView!
    @IBOutlet weak var contentTableView: UITableView!
    @IBOutlet weak var headerHeightConstraint: NSLayoutConstraint!

    internal var inExtensionContext: Bool {
        return self.extensionContext != nil
    }
    internal var URL: NSURL?
    internal var openURLAction: ((NSURL) -> Void)?

    private var contentSections: [[(String, AnyObject)]]?
    private var contentSectionNames: [CertificateInfoSection]?
    private var inspectingUrl: NSURL?
    private var targetHost = ""
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

            guard let index = self.selectedIndex else {
                return
            }
            let indexPath = NSIndexPath(forRow: index, inSection: 0)
            self.headerTableView.selectRowAtIndexPath(indexPath, animated: false, scrollPosition: .None)
        }
    }

    private func updateStatistics(host: String) {
        let defaults = NSUserDefaults.standardUserDefaults()
        #if DEBUG
            defaults.setBool(false, forKey: kRatingKey)
        #endif
        var stats = defaults.integerForKey(kStatisticsKey)
        stats += 1
        if self.inExtensionContext && !defaults.boolForKey(kRatingKey) {
            if stats >= 5 {
                let alert = UIAlertController(title: "Hooray", message: "You have inspected \(stats) sites. :)", preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "Next Time", style: .Default, handler: nil))
                alert.addAction((UIAlertAction(title: "Rate us", style: .Default, handler: { (action) -> Void in
                    self.extensionOpenUrl(kAppStoreHTTPUrl)
                })))
                alert.popoverPresentationController?.sourceView = self.view
                alert.popoverPresentationController?.sourceRect = self.view.frame
                self.presentViewController(alert, animated: true, completion: nil)
                defaults.setBool(true, forKey: kRatingKey)
            }
        }
        defaults.setInteger(stats, forKey: kStatisticsKey)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navItem?.title = "Inspect - Certificate"
        if self.inExtensionContext {
            self.viewDidLoadInExtensionContext()
        } else {
            self.configureTableViews()
            self.parse(self.URL, error: nil)
        }
    }

    override func viewDidLayoutSubviews() {
        if self.headerTableView.contentSize.height > self.headerHeightConstraint.constant {
            dispatch_async(dispatch_get_main_queue(), {
                //print("set actual height = \(self.headerTableView.contentSize.height)")
                self.headerHeightConstraint.constant = self.headerTableView.contentSize.height
            })
        }

    }

    // MARK: Action
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    private func viewDidLoadInExtensionContext() {
        var once: dispatch_once_t = 0
        dispatch_once(&once) { () -> Void in
            Fabric.with([Answers.self, Crashlytics.self])
        }

        var validItemProvider: NSItemProvider?
        guard let extensionContext = self.extensionContext else { return }
        nestedLoop: for item: AnyObject in extensionContext.inputItems {
            guard let inputItem = item as? NSExtensionItem else {
                continue
            }
            for provider: AnyObject in inputItem.attachments! {
                guard let itemProvider = provider as? NSItemProvider else {
                    continue
                }
                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                    validItemProvider = itemProvider
                    break nestedLoop
                }
            }
        }
        guard validItemProvider != nil else { return self.showError("no valid item privoder!") }

        self.configureTableViews()
        validItemProvider!.loadItemForTypeIdentifier(kUTTypeURL as String, options: nil, completionHandler: { (item, error) -> Void in
            self.parse(item, error: error)
        })
    }

    private func parse(item: AnyObject?, error: NSError?) {
        if let url = item as? NSURL? {
            self.inspectingUrl = url
            if let urlString = url?.absoluteString {
                Answers.logCustomEventWithName(kActionInspect, customAttributes:["url": urlString, "in_extension": self.inExtensionContext])
            }
            print("get url \(url), scheme = \(url?.scheme)")
            if url?.scheme == ("https") {
                self.targetHost = (url?.host)!
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    INHUD.sharedHUD.contentView = INHUDTextView(text: "Fetching Certificates…")
                    INHUD.sharedHUD.showInView(self.view)
                })
                SessionManager.sharedManager.fetchCertsForUrl(url!, completion: { (certs) -> Void in
                    INHUD.sharedHUD.hide()
                    if certs.count > 0 {
                        self.certificates = certs
                        self.selectedIndex = certs.count - 1
                        self.updateStatistics(self.targetHost)
                    }
                })
                WOT.query(self.targetHost) { result in
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
    }
    @IBAction func done() {
        if self.inExtensionContext {
            self.extensionContext!.completeRequestReturningItems(self.extensionContext!.inputItems, completionHandler: nil)
        } else {
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }

    @IBAction func share() {
        let sheet = UIAlertController(title: "More Options", message: nil, preferredStyle: .ActionSheet)
        sheet.addAction(UIAlertAction(title: "Scan in SSLLabs.com", style: .Default, handler: { (action) -> Void in
            if self.inspectingUrl != nil {
                if let url = SSLLabs.scanUrl((self.inspectingUrl?.host)!) {
                    Answers.logCustomEventWithName(kActionScanInSSLLabs, customAttributes: ["in_extension": self.inExtensionContext])
                    let vc = SFSafariViewController(URL: url)
                    self.presentViewController(vc, animated: true, completion: nil)
                }
            }
        }))

        sheet.addAction(UIAlertAction(title: "Export Certificate", style: .Default, handler: { (action) -> Void in
            if self.selectedIndex == nil {
                self.selectedIndex = self.certificates.count - 1
            }
            Answers.logCustomEventWithName(kActionExport, customAttributes: ["index": self.selectedIndex!, "in_extension": self.inExtensionContext])
            let cert = self.certificates[self.selectedIndex!]
            let data = SecCertificateCopyData(cert.0) as NSData
            let exportItem = ExportItemSource(data: data, host: self.targetHost, index: self.selectedIndex!)
            let vc = UIActivityViewController(activityItems: [exportItem], applicationActivities: nil)
            vc.popoverPresentationController?.barButtonItem = self.navItem.rightBarButtonItem
            self.presentViewController(vc, animated: true, completion: nil)
        }))

        sheet.addAction(UIAlertAction(title: "Feedback", style: .Default, handler: { (action) -> Void in
            Answers.logCustomEventWithName(kActionFeedback, customAttributes: ["in_extension": true])
            if self.feedbackCanSendMail() {
                self.feedbackWithEmail()
            } else {
                self.extensionOpenUrl(self.feedbackMailToString())
            }
        }))

        sheet.popoverPresentationController?.barButtonItem = self.navItem.rightBarButtonItem
        sheet.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        self.presentViewController(sheet, animated: true, completion: nil)
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
        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = self.view.frame
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
        attachment.bounds = CGRect(x: 4, y: -4, width: 20, height: 20)
        string.appendAttributedString(NSAttributedString(attachment: attachment))
        textView.attributedText = string
        textView.sizeToFit()
        textView.editable = false
        return textView
    }

    private func extensionOpenUrl(urlString: String) {

        guard let url = NSURL(string: urlString) else {return}

        if let action = self.openURLAction {
            action(url)
            return
        }

        var responder = self as UIResponder?
        while let r = responder {
            let sel = NSSelectorFromString("openURL:")
            if r.respondsToSelector(sel) {
                r.performSelector(sel, withObject: url)
            }
            responder = r.nextResponder()
        }
    }
}

// MARK: UITableViewDelegate
extension ActionViewController {
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if tableView == self.headerTableView {
            let cert = self.certificates[indexPath.row]
            let cell = tableView.dequeueReusableCellWithIdentifier(CertificateStackCell.reuseId) as? CertificateStackCell
            cell?.trustResult = cert.1
            cell?.level = indexPath.row
            if let name = SecCertificateCopySubjectSummary(cert.0) {
                cell?.name = name as String
            }
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
}
