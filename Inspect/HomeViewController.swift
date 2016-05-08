//
//  HomeViewController.swift
//  Inspect
//
//  Created by hewig on 5/6/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit
import MessageUI

enum HomeSection: Int {
    case Tutorial = 0
    case Misc = 1
    case Safari = 2

    enum Item: String {
        case HowToUseIt = "How to use it"
        case Feedback = "Feedback"
        case RateUs = "Rate us"
        case OpenSafari = "Open Safari"
    }

    var reuseId: String {
        switch self {
        case .Safari:
            return "HomeCellForSafari"
        default:
            return "HomeCell"
        }
    }

    var sectionTitle: String {
        switch self {
        case .Tutorial: return "Tutorial".uppercaseString
        case .Misc: return "Misc".uppercaseString
        case .Safari: return "Inspect HTTPS Sites".uppercaseString
        }
    }

    var sections: [Item] {
        switch self {
        case .Tutorial:return [.HowToUseIt]
        case .Misc: return [.Feedback, .RateUs]
        case .Safari: return [.OpenSafari]
        }
    }
}

class HomeViewController: UIViewController,
                          UITableViewDelegate, UITableViewDataSource {

    private let cellHeight: CGFloat = UIScreen.mainScreen().scale * 22
    private let sectionHeight: CGFloat = 56
    private let sectionLeftPadding: CGFloat = UIScreen.mainScreen().scale >= 3.0 ? 20: 15
    private let sectionTopPadding: CGFloat = 30

    private let footerText: String = {
        var version = "dev"; var build = "9999"
        if let infoDict = NSBundle.mainBundle().infoDictionary {
            if let v = infoDict["CFBundleShortVersionString"] as? String {version = v}
            if let v = infoDict["CFBundleVersion"] as? String { build = v}
        }
        var text = "Version: \(version)(\(build))\n"
        text += "Credits: OpenSSL / ZipZap\n"
        text += "Made with ♥ by Fourplex Labs"
        return text
    }()

    private let dataSource: [HomeSection] = {
        return [.Tutorial, .Misc, .Safari]
    }()

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: self.view.frame, style: .Grouped)
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: HomeSection.Tutorial.reuseId)
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: HomeSection.Safari.reuseId)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = self.footerView
        tableView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
        return tableView
    }()

    lazy var footerView: UIView = {
        let view = UIView(); let label = UILabel()
        label.textColor = UIColor.lightGrayColor()
        label.font = UIFont.systemFontOfSize(12)
        label.numberOfLines = 0
        label.textAlignment = .Center
        label.text = self.footerText
        let size = label.sizeThatFits(CGSize(width: self.view.fp_width - 2 * self.sectionLeftPadding, height: CGFloat.max))
        label.frame.size = size
        label.fp_x = (self.view.fp_width - size.width) / 2
        label.fp_y = self.sectionTopPadding * 2
        view.addSubview(label)
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Inspect"
        self.view.addSubview(tableView)
        if NSUserDefaults.standardUserDefaults().boolForKey(kFirstRun) {
            self.showTutorial()
        }
    }

    func showTutorial() {
        let vc = TutorialViewController()
        self.navigationController?.presentViewController(vc, animated: true, completion: nil)
    }
}

//MARK: UITableViewDelegate / UITableViewDataSource

extension HomeViewController {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return dataSource.count
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = dataSource[section]
        return section.sections.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let font = UIFont.systemFontOfSize(20)
        guard let section = HomeSection(rawValue: indexPath.section) else {
            return UITableViewCell(style: .Default, reuseIdentifier: nil)
        }
        let cell = UITableViewCell(style: .Default, reuseIdentifier: section.reuseId)
        let items = section.sections
        switch section {
        case .Safari:
            let label = UILabel()
            label.textColor = self.view.tintColor
            label.font = font
            label.text = items[indexPath.row].rawValue
            label.sizeToFit()
            label.fp_x = (tableView.fp_width - label.fp_width) / 2; label.fp_y = (cellHeight - label.fp_height) / 2
            cell.addSubview(label)
            break
        default:
            cell.textLabel?.font = font
            cell.textLabel?.text = items[indexPath.row].rawValue
        }
        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard let section = HomeSection(rawValue: indexPath.section) else {return}
        switch section {
        case .Safari:
            if let url = NSURL(string: kAppStoreHTTPUrl) {
                UIApplication.sharedApplication().openURL(url)
            }
            break
        case .Tutorial:
            self.showTutorial()
            break
        case .Misc:
            let item = section.sections[indexPath.row]
            switch item {
            case .Feedback:
                self.feedbackWithEmail()
                break
            case .RateUs:
                if let url = NSURL(string: kAppStoreUrl) {
                    UIApplication.sharedApplication().openURL(url)
                }
            default:break
            }
            break
        }
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }

    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sectionHeight
    }

    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return cellHeight
    }

    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView(); let label = UILabel()
        label.textColor = UIColor.darkGrayColor()
        label.font = UIFont.systemFontOfSize(14)

        let s = HomeSection(rawValue: section)
        label.text = s?.sectionTitle
        label.sizeToFit(); label.fp_x = sectionLeftPadding; label.fp_y = sectionTopPadding
        view.addSubview(label)
        return view
    }
}
