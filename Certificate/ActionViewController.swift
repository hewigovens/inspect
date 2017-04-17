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
import Reusable

class ActionViewController: UIViewController,
                            UITableViewDelegate,
                            UITableViewDataSource,
                            UIActionSheetDelegate {

    private lazy var __once: () = { () -> Void in
        Fabric.with([Answers.self, Crashlytics.self])
    }()

    @IBOutlet internal weak var navItem: UINavigationItem!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var headerTableView: UITableView!
    @IBOutlet weak var contentTableView: UITableView!
    @IBOutlet weak var headerHeightConstraint: NSLayoutConstraint!

    internal var inExtensionContext: Bool {
        return self.extensionContext != nil
    }
    internal var URL: Foundation.URL?
    internal var openURLAction: ((Foundation.URL) -> Void)?
    internal var rootCAs: [String: AnyObject]? = nil
    internal var evSet: [String: AnyObject]? = nil

    fileprivate var documentController: UIDocumentInteractionController?
    fileprivate var http2capable = false
    fileprivate var contentSections: [[(String, AnyObject)]]?
    fileprivate var contentSectionNames: [CertificateInfoSection]?
    fileprivate var inspectingUrl: Foundation.URL?
    fileprivate var targetHost = ""
    fileprivate var selectedCertInfo: [[String: String]] = []
    fileprivate var x509Certs: [X509Certificate] = []
    fileprivate var certificates: [(secCert: SecCertificate, secTrust: SecTrustResultType)] = [] {
        didSet {
            self.x509Certs = self.certificates.map({ (certificate) -> X509Certificate in
                return X509Certificate(certificate: certificate.0)
            })
            self.headerTableView.isHidden = false
            self.contentTableView.isHidden = false
            self.headerHeightConstraint.constant = CGFloat(48 * self.certificates.count)
            self.headerTableView.reloadData()
        }
    }
    fileprivate var selectedIndex: Int? {
        didSet {
            guard let index = self.selectedIndex else { return }
            if index < 0 || index >= self.x509Certs.count {
                return
            }
            let cert = self.x509Certs[index]
            let tuples = cert.displaySections()
            self.contentSections = tuples.sectionData
            self.contentSectionNames = tuples.sectionName

            let indexPath = IndexPath(row: index, section: 0)
            self.headerTableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)

        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.contentTableView.rowHeight = UITableViewAutomaticDimension
        self.contentTableView.register(cellType: CertificateInfoCell.self)
        self.contentTableView.register(cellType: CertificateInfoCell2.self)
        self.navItem?.title = "Inspect - Certificate"
        if self.inExtensionContext {
            self.viewDidLoadInExtensionContext()
        } else {
            self.configureTableViews()
            self.parse(self.URL as AnyObject?, error: nil)
        }
        loadRootCAs()
    }

    override func viewDidLayoutSubviews() {
        if self.headerTableView.contentSize.height > self.headerHeightConstraint.constant {
            DispatchQueue.main.async(execute: {
                //print("set actual height = \(self.headerTableView.contentSize.height)")
                self.headerHeightConstraint.constant = self.headerTableView.contentSize.height
            })
        }

    }

    // MARK: Action
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    fileprivate func viewDidLoadInExtensionContext() {
        _ = self.__once

        var validItemProvider: NSItemProvider?
        guard let extensionContext = self.extensionContext else { return }
        nestedLoop: for item: Any in extensionContext.inputItems {
            guard let inputItem = item as? NSExtensionItem else {
                continue
            }
            for provider in inputItem.attachments! {
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
        validItemProvider!.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil, completionHandler: { (item, error) -> Void in
            self.parse(item, error: error)
        })
    }

    fileprivate func parse(_ item: AnyObject?, error: Error?) {
        if let url = item as? Foundation.URL? {
            self.inspectingUrl = url
            if let urlString = url?.absoluteString {
                Answers.logCustomEvent(withName: kActionInspect, customAttributes:["url": urlString, "in_extension": self.inExtensionContext])
            }
            print("get url \(String(describing: url)), scheme = \(String(describing: url?.scheme))")
            if url?.scheme == ("https") {
                self.targetHost = (url?.host)!
                DispatchQueue.main.async(execute: { () -> Void in
                    INHUD.sharedHUD.contentView = INHUDTextView(text: "Fetching Certificates…")
                    INHUD.sharedHUD.showInView(self.view)
                })
                SessionManager.shared.fetchCertsForUrl(url!, completion: { (certs) -> Void in
                    INHUD.sharedHUD.hide()
                    if certs.count > 0 {
                        self.certificates = certs
                        self.selectedIndex = certs.count - 1
                        self.updateStatistics(self.targetHost)
                    }
                })

                HTTP2Probe.probeURL(url!, completion: { result in
                    self.http2capable = result
                    WOT.query(self.targetHost) { result in
                        debugPrint(result)
                        switch result {
                        case .success(let record):
                            self.showWOTRating(record)
                        case .failure(let error):
                            #if DEBUG
                                self.showError(error)
                            #endif
                        }
                    }
                })
            } else {
                self.showError("\(url!) seems not a https URL")
            }
        } else {
            self.showError("url is not valid NSURL object")
        }
    }
    @IBAction func done() {
        if self.inExtensionContext {
            self.extensionContext!.completeRequest(returningItems: self.extensionContext!.inputItems, completionHandler: nil)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    @IBAction func share() {
        let sheet = UIAlertController(title: "More Options", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Scan in SSLLabs.com", style: .default, handler: { (action) -> Void in
            if self.inspectingUrl != nil {
                if let url = SSLLabs.scanUrl((self.inspectingUrl?.host)!) {
                    Answers.logCustomEvent(withName: kActionScanInSSLLabs, customAttributes: ["in_extension": self.inExtensionContext])
                    let vc = SFSafariViewController(url: url)
                    self.present(vc, animated: true, completion: nil)
                }
            }
        }))

        sheet.addAction(UIAlertAction(title: "Export Certificate", style: .default, handler: { (action) -> Void in
            if self.selectedIndex == nil {
                self.selectedIndex = self.certificates.count - 1
            }
            Answers.logCustomEvent(withName: kActionExport, customAttributes: ["index": self.selectedIndex!, "in_extension": self.inExtensionContext])
            guard let index = self.selectedIndex else { return }
            if index < 0 || index >= self.certificates.count {
                return
            }
            let cert = self.certificates[index]
            let data = SecCertificateCopyData(cert.0) as Data
            let exportItem = ExportItemSource(data: data, host: self.targetHost, index: index)

            guard let path = exportItem.saveToDisk() else {
                return
            }
            let vc = UIDocumentInteractionController(url: path)
            vc.presentOptionsMenu(from: self.navItem.rightBarButtonItem!, animated: true)
            self.documentController = vc
        }))

        sheet.addAction(UIAlertAction(title: "Feedback", style: .default, handler: { (action) -> Void in
            Answers.logCustomEvent(withName: kActionFeedback, customAttributes: ["in_extension": true])
            if self.feedbackCanSendMail() {
                self.feedbackWithEmail()
            } else {
                self.extensionOpenUrl(self.feedbackMailToString())
            }
        }))

        sheet.popoverPresentationController?.barButtonItem = self.navItem.rightBarButtonItem
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(sheet, animated: true, completion: nil)
    }

    // MARK: Private funcs

    fileprivate func configureTableViews() {

        // Certificate Stack View
        self.headerTableView.bounces = false
        self.headerTableView.separatorStyle = .none
        self.headerTableView.rowHeight = UITableViewAutomaticDimension
        self.headerTableView.estimatedRowHeight = 44
        self.headerTableView.backgroundColor = UIColor.lightText
        self.headerTableView.isHidden = true

        self.contentTableView.estimatedRowHeight = 100
        self.contentTableView.rowHeight = UITableViewAutomaticDimension
        self.contentTableView.isHidden = true
    }

    fileprivate func showWOTRating(_ record: Record) {
        DispatchQueue.main.async { () -> Void in
            self.navItem?.titleView = self.genTitleView(record)
        }
    }

    fileprivate func showMITMAlert() {
        if self.presentedViewController == nil {
            let errorMessage = "The Root CA is not trusted. You may be under MITM attack."
            let alert = UIAlertController(title: "Warning", message: errorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .destructive, handler: nil))
            alert.popoverPresentationController?.sourceView = self.view
            alert.popoverPresentationController?.sourceRect = self.view.frame
            DispatchQueue.main.async { () -> Void in
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    fileprivate func showError(_ errorMessage: String) {
        print("error \(errorMessage)")

        let alert = UIAlertController(title: "Error", message: errorMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = self.view.frame
        DispatchQueue.main.async { () -> Void in
            self.present(alert, animated: true, completion: nil)
        }
    }

    fileprivate func showError(_ error: NSError) {
        return self.showError(error.description)
    }

    fileprivate func genTitleView(_ record: Record) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = UIColor.clear

        let h2Attachment = NSTextAttachment()
        if self.http2capable {
            h2Attachment.image = #imageLiteral(resourceName: "IndicatorH2")
        } else {
            h2Attachment.image = #imageLiteral(resourceName: "IndicatorNone")
        }
        h2Attachment.bounds = CGRect(x: 4, y: -4, width: 20, height: 20)
        let string = NSMutableAttributedString()
        string.append(NSAttributedString(attachment: h2Attachment))
        string.append(NSAttributedString(string: "\(record.reputation.rawValue): ", attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 16)]))
        let attachment = NSTextAttachment()
        attachment.image = UIImage(named: "WOT\(record.reputation.rawValue)")
        attachment.bounds = CGRect(x: 4, y: -4, width: 20, height: 20)
        string.append(NSAttributedString(attachment: attachment))
        textView.attributedText = string
        textView.sizeToFit()
        textView.isEditable = false
        return textView
    }
}

// MARK: UITableViewDelegate
extension ActionViewController {
    @objc(tableView:cellForRowAtIndexPath:) func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == self.headerTableView {
            let cert = self.certificates[indexPath.row]
            let x509Cert = self.x509Certs[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: CertificateStackCell.reuseId, for: indexPath) as? CertificateStackCell
            cell?.trustResult = cert.secTrust

            if let rootCAs = self.rootCAs,
               let evSet = self.evSet {
                let dict = rootCAs[self.x509Certs[0].sha256] as? [String: AnyObject]
                // MITM check
                if indexPath.row == 0 && (cert.secTrust == .unspecified ||
                    cert.secTrust == .proceed) && dict == nil {
                    cell?.trustResult = .otherError
                    self.showMITMAlert()
                }

                for policy in x509Cert.policyIds {
                    if evSet[policy] != nil {
                        cell?.isEV = true
                    }
                }
            }

            if let name = SecCertificateCopySubjectSummary(cert.secCert) {
                cell?.name = name as String
            }
            if let isEV = cell?.isEV, isEV == true {
                if let o = x509Cert.subjectDict["O"] {
                    cell?.name = "\(o) - \((cell?.name)!)"
                }
            }

            cell?.level = (indexPath as NSIndexPath).row
            return cell!
        } else {
            let cell: CertificateInfoCell = tableView.dequeueReusableCell(for: indexPath)

            guard self.x509Certs.count > 0 else {
                return cell
            }

            let sections = self.contentSections!
            let section = sections[(indexPath as NSIndexPath).section]
            let tuple = section[(indexPath as NSIndexPath).row]
            let sectionType = self.contentSectionNames![(indexPath as NSIndexPath).section]
            if sectionType == .PubKeyInfo ||
                sectionType == .Fingerprints ||
                sectionType == .Signature ||
                sectionType == .Extensions {
                let cell2: CertificateInfoCell2 = tableView.dequeueReusableCell(for: indexPath)
                cell2.titleLabel.text = tuple.0
                cell2.longTextLabel.numberOfLines = 0
                cell2.longTextLabel.text = tuple.1 as? String
                if sectionType != .Extensions {
                    cell2.longTextLabel.font = UIFont(name: "Courier", size: 15)
                } else {
                    cell2.longTextLabel.font = UIFont.systemFont(ofSize: 15)
                }
                cell2.invalidateIntrinsicContentSize()
                return cell2
            } else {
                cell.titleLabel.text = tuple.0
                cell.detailLabel.numberOfLines = 0
                cell.detailLabel.text = tuple.1 as? String
                return cell
            }
        }
    }

    @objc(numberOfSectionsInTableView:) func numberOfSections(in tableView: UITableView) -> Int {
        if tableView == self.headerTableView {
            return 1
        } else {
            return self.contentSectionNames?.count ?? 0
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.headerTableView {
            return certificates.count
        } else {
            if let sections = self.contentSections {
                return sections[section].count
            }
            return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if tableView == self.contentTableView {
            return self.contentSectionNames?[section].rawValue ?? nil
        }
        return nil
    }

    @objc(tableView:didSelectRowAtIndexPath:) func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == self.headerTableView {
            self.selectedIndex = (indexPath as NSIndexPath).row
            self.contentTableView.reloadData()
            self.contentTableView.setNeedsLayout()
            self.contentTableView.layoutIfNeeded()
        } else {
            let sections = self.contentSections!
            let section = sections[(indexPath as NSIndexPath).section]
            let tuple = section[(indexPath as NSIndexPath).row]
            UIPasteboard.general.setValue(tuple.1, forPasteboardType: kUTTypePlainText as String)
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}
