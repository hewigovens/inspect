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
import FontAwesomeKit
import Reusable
import StoreKit
import SafariServices

class HomeViewController: UIViewController {
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    let dataSource: [HomeSection] = [.tutorial, .misc]

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: self.view.frame, style: .grouped)
        tableView.register(cellType: HomeCell.self)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = cellHeight
        tableView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        tableView.tableFooterView = UIView()
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNaviItems()
        configureSubviews()

        if UserDefaults.standard.bool(forKey: kFirstRun) {
            self.showTutorial()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.tableView.reloadData()
        }, completion: nil)
    }

    func configureNaviItems() {
        self.title = "Inspect"
        let leftSize: CGFloat = 24
        let leftIcon = FAKIonIcons.iosClockOutlineIcon(withSize: leftSize)
        leftIcon?.addAttribute(NSAttributedStringKey.foregroundColor.rawValue, value: UIColor.black)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: leftIcon?.image(with: CGSize(width: leftSize, height: leftSize)), style: .plain, target: self, action: #selector(showHistory))

        let rightSize: CGFloat = 24
        let rightIcon = FAKIonIcons.iosSearchIcon(withSize: rightSize)
        rightIcon?.addAttribute(NSAttributedStringKey.foregroundColor.rawValue, value: UIColor.black)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: rightIcon?.image(with: CGSize(width: rightSize, height: rightSize)), style: .plain, target: self, action: #selector(showInspect))
    }

    func configureSubviews() {
        self.view.addSubview(tableView)
    }

    @objc func showHistory() {
        let vc = HistoryViewController()
        let nav = UINavigationController(rootViewController: vc)
        self.present(nav, animated: true, completion: nil)
    }

    @objc func showInspect() {
        let actions = UIAlertController(title: "Inspect", message: "select available methods below", preferredStyle: .actionSheet)

        actions.addAction(UIAlertAction(title: "Open Safari", style: .default, handler: { [weak self] _ in
            self?.openUrl("https://www.apple.com")
        }))

        if let url = URL(string: kGoogleChromeScheme), UIApplication.shared.canOpenURL(url) {
            actions.addAction(UIAlertAction(title: "Open Chrome", style: .default, handler: { [weak self] _ in
                self?.openUrlInChrome("www.google.com")
            }))
        }

        actions.addAction(UIAlertAction(title: "Input manually", style: .default, handler: { [weak self] _ in
            let alert = UIAlertController(title: "Input manually", message: "Input or paste a https url to continue", preferredStyle: .alert)
            alert.addTextField(configurationHandler: { textField in
                textField.placeholder = "https://"
                guard let pasted = UIPasteboard.general.string else {return}
                guard let url = URL(string: pasted), url.scheme == "https" else {return}
                textField.text = pasted
            })

            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] _ in
                guard let string = alert?.textFields?.first?.text else { return }
                guard let url = URL(string: string) else { return }
                guard let vc = ActionViewController.create(url: url) else { return }
                vc.openURLAction = { url in
                    if UIApplication.shared.canOpenURL(url as URL) {
                        UIApplication.shared.openURL(url as URL)
                    }
                }
                self?.present(vc, animated: true, completion: nil)
            }))

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.popoverPresentationController?.barButtonItem = self?.navigationItem.rightBarButtonItem
            alert.popoverPresentationController?.sourceView = self?.view
            self?.present(alert, animated: true, completion: nil)
        }))

        actions.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        actions.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        actions.popoverPresentationController?.sourceView = self.view
        self.present(actions, animated: true, completion: nil)
    }

    func showTutorial() {
        Answers.logCustomEvent(withName: kActionTutorial, customAttributes: nil)
        let vc = TutorialViewController()
        self.navigationController?.present(vc, animated: true, completion: nil)
    }
}

// MARK: UITableViewDelegate / UITableViewDataSource
extension HomeViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = dataSource[section]
        return section.sections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: HomeCell = tableView.dequeueReusableCell(for: indexPath)
        guard let section = HomeSection(rawValue: indexPath.section) else {
            return cell
        }
        cell.separatorInset = UIEdgeInsets(top: 0, left: sectionLeftPadding, bottom: 0, right: 0)
        let item = section.sections[indexPath.row]
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15)
        cell.textLabel?.text = item.rawValue
        cell.textLabel?.textColor = UIColor(white: 0.25, alpha:1.00)
        cell.textLabel?.textAlignment = .left
        cell.imageView?.image = item.image
        if item == .about {
            var label = cell.accessoryView as? UILabel
            if label == nil {
                label = UILabel()
                label?.font = UIFont.systemFont(ofSize: 14)
                label?.textColor = UIColor(white: 0.25, alpha: 1)
                cell.accessoryView = label
            }
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Dev"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "9999"
            label?.text = "Version: \(version)(\(build))"
            label?.sizeToFit()
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = HomeSection(rawValue: (indexPath as NSIndexPath).section) else {return}
        let item = section.sections[(indexPath as NSIndexPath).row]
        switch section {
        case .tutorial:
            self.showTutorial()
            break
        case .misc:
            if item == .feedback {
                Answers.logCustomEvent(withName: kActionFeedback, customAttributes: ["in_extension": false])
                if self.feedbackCanSendMail() {
                    self.feedbackWithEmail()
                } else {
                    self.openUrl(self.feedbackMailToString())
                }
            } else if item == .rateUs {
                Answers.logCustomEvent(withName: kActionRate, customAttributes: nil)
                if #available(iOS 10.3, *) {
                    SKStoreReviewController.requestReview()
                } else {
                    if let url = URL(string: kAppStoreHTTPUrl) {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.openURL(url)
                        }
                    }
                }
            } else if item == .about {
                guard let url = URL(string: kAboutUrl) else { return }
                let vc = SFSafariViewController(url: url)
                self.present(vc, animated: true, completion: nil)
            }
            break
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sectionHeight
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
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
