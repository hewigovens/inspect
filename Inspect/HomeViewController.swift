//
//  HomeViewController.swift
//  Inspect
//
//  Created by hewig on 5/6/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit
import MessageUI
import Crashlytics

enum HomeSection: Int {
    case tutorial = 0
    case misc = 1
    case safari = 2
    case history = 3

    enum Item: String {
        case HowToUseIt = "How to use it"
        case Feedback = "Send Feedback"
        case RateUs = "Rate on App Store"
        case OpenSafari = "Open Safari"
        case OpenChrome = "Open Chrome"
        case History = "History"
    }

    var reuseId: String {
        switch self {
        case .safari:
            return "HomeCellForSafari"
        default:
            return "HomeCell"
        }
    }

    var sectionTitle: String {
        switch self {
        case .tutorial: return "Tutorial".uppercased()
        case .misc: return "Misc".uppercased()
        case .safari: return "Inspect HTTPS Sites".uppercased()
        case .history: return "Recent Lookup Histories".uppercased()
        }
    }

    var sections: [String] {

        var browsers = [Item.OpenSafari.rawValue]

        if let url = URL(string: kGoogleChromeScheme) {
            if UIApplication.shared.canOpenURL(url) {
                browsers.append(Item.OpenChrome.rawValue)
            }
        }

        var history = [String]()
        if let defaults = UserDefaults.init(suiteName: kInspectGroupId) {
            if let hosts = defaults.stringArray(forKey: kHistoryKey) {
                history =  hosts
            }
        }

        switch self {
        case .tutorial:return [Item.HowToUseIt.rawValue]
        case .misc: return [Item.Feedback.rawValue, Item.RateUs.rawValue]
        case .safari: return browsers
        case .history: return history
        }
    }
}

internal let cellHeight: CGFloat = UIScreen.main.scale * 22
internal let sectionHeight: CGFloat = 56
internal let sectionLeftPadding: CGFloat = UIScreen.main.scale >= 3.0 ? 20: 15
internal let sectionTopPadding: CGFloat = 30

class HomeCell: UITableViewCell {
    override func layoutSubviews() {
        super.layoutSubviews()
        self.textLabel?.fp_x = sectionLeftPadding
    }
}

class HomeViewController: UIViewController,
                          UITableViewDelegate, UITableViewDataSource {

    fileprivate let footerText: String = {
        var version = "dev"; var build = "9999"
        if let infoDict = Bundle.main.infoDictionary {
            if let v = infoDict["CFBundleShortVersionString"] as? String {version = v}
            if let v = infoDict["CFBundleVersion"] as? String { build = v}
        }
        var text = "Version: \(version)(\(build))\n"
        text += "Credits: OpenSSL / ZipZap\n"
        text += "Made with ♥ by Fourplex Labs"
        return text
    }()

    fileprivate let dataSource: [HomeSection] = {
        return [.tutorial, .misc, .safari, .history]
    }()

    var footerTextY: CGFloat {
        var y = sectionTopPadding * 2 - 10
        if self.view.fp_height <= 480 {
            // iPhone 4
            y -= 30
        }
        return y
    }

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: self.view.frame, style: .grouped)
        tableView.register(HomeCell.self, forCellReuseIdentifier: HomeSection.tutorial.reuseId)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: HomeSection.safari.reuseId)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = cellHeight
        tableView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        return tableView
    }()

    func createfooterView() -> UIView {
        let view = UIView(); let label = UILabel()
        label.textColor = UIColor.lightGray
        label.font = UIFont.systemFont(ofSize: 12)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = self.footerText
        let size = label.sizeThatFits(CGSize(width: self.view.fp_width - 2 * sectionLeftPadding, height: CGFloat.greatestFiniteMagnitude))
        label.frame.size = size
        label.fp_x = (self.view.fp_width - size.width) / 2
        label.fp_y = self.footerTextY
        view.addSubview(label)
        return view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Inspect"
        self.view.addSubview(tableView)
        if UserDefaults.standard.bool(forKey: kFirstRun) {
            self.showTutorial()
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.reloadHistory()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.reloadHistory()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { (context) in
            self.tableView.reloadData()
        }, completion: nil)
    }

    func showTutorial() {
        Answers.logCustomEvent(withName: kActionTutorial, customAttributes: nil)
        let vc = TutorialViewController()
        self.navigationController?.present(vc, animated: true, completion: nil)
    }

    func reloadHistory() {
        self.tableView.reloadSections([3], with: .automatic)
    }
}

//MARK: UITableViewDelegate / UITableViewDataSource
extension HomeViewController {
    @objc(numberOfSectionsInTableView:) func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = dataSource[section]
        return section.sections.count
    }

    @objc(tableView:cellForRowAtIndexPath:) func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let font = UIFont.systemFont(ofSize: 20)
        guard let section = HomeSection(rawValue: (indexPath as NSIndexPath).section) else {
            return UITableViewCell(style: .default, reuseIdentifier: nil)
        }
        let cell = HomeCell(style: .default, reuseIdentifier: section.reuseId)
        cell.separatorInset = UIEdgeInsets(top: 0, left: sectionLeftPadding, bottom: 0, right: 0)
        let items = section.sections
        switch section {
        case .safari:
            let label = UILabel()
            label.textColor = self.view.tintColor
            label.font = font
            label.text = items[(indexPath as NSIndexPath).row]
            label.sizeToFit()
            label.fp_x = (tableView.fp_width - label.fp_width) / 2; label.fp_y = (cellHeight - label.fp_height) / 2
            cell.addSubview(label)
            break
        default:
            cell.textLabel?.font = font
            cell.textLabel?.text = items[(indexPath as NSIndexPath).row]
            cell.textLabel?.textColor = UIColor(red:0.25, green:0.25, blue:0.25, alpha:1.00)
            cell.textLabel?.textAlignment = .left
        }
        return cell
    }

    @objc(tableView:didSelectRowAtIndexPath:) func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = HomeSection(rawValue: (indexPath as NSIndexPath).section) else {return}
        let item = section.sections[(indexPath as NSIndexPath).row]
        switch section {
        case .safari:
            if item == HomeSection.Item.OpenSafari.rawValue {
                self.openUrl("https://www.apple.com")
            } else if item == HomeSection.Item.OpenChrome.rawValue {
                self.openUrlInChrome("www.google.com")
            }
            break
        case .tutorial:
            self.showTutorial()
            break
        case .misc:
            if item == HomeSection.Item.Feedback.rawValue {
                Answers.logCustomEvent(withName: kActionFeedback, customAttributes: ["in_extension": false])
                if self.feedbackCanSendMail() {
                    self.feedbackWithEmail()
                } else {
                    self.openUrl(self.feedbackMailToString())
                }
            } else if item == HomeSection.Item.RateUs.rawValue {
                Answers.logCustomEvent(withName: kActionRate, customAttributes: nil)
                if let url = URL(string: kAppStoreHTTPUrl) {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.openURL(url)
                    }
                }
            }
            break
        case.history:
            guard let url = URL(string: "https://" + item) else {return}
            guard let vc = ActionViewController.create(url: url) else {return}
            vc.openURLAction = { url in
                if UIApplication.shared.canOpenURL(url as URL) {
                    UIApplication.shared.openURL(url as URL)
                }
            }
            self.present(vc, animated: true, completion: nil)
            break
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sectionHeight
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {

        guard let sec = HomeSection(rawValue: section) else {
            return CGFloat.leastNormalMagnitude
        }
        switch sec {
        case .history: return 100
        default: return CGFloat.leastNormalMagnitude
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView(); let label = UILabel()
        label.textColor = UIColor.darkGray
        label.font = UIFont.systemFont(ofSize: 14)

        let s = HomeSection(rawValue: section)
        label.text = s?.sectionTitle
        label.sizeToFit(); label.fp_x = sectionLeftPadding; label.fp_y = sectionTopPadding
        view.addSubview(label)
        return view
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {

        guard let sec = HomeSection(rawValue: section) else {
            return nil
        }
        switch sec {
        case .history: return self.createfooterView()
        default: return nil
        }
    }

    func openUrl(_ urlString: String) {
        if let url = URL(string: urlString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.openURL(url)
            }
        }
    }

    func openUrlInChrome(_ urlString: String) {
        self.openUrl(kGoogleChromeScheme + urlString)
    }
}
