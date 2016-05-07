//
//  HomeViewController.swift
//  Inspect
//
//  Created by hewig on 5/6/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit

enum HomeSection: String {
    case Tutorial = "Tutorial"
    case Safari = "Inspect HTTPS Sites"
}

class HomeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private let cellHeight: CGFloat = 44
    private let sectionHeight: CGFloat = 56
    private let sectionLeftPadding: CGFloat = 20
    private let sectionTopPadding: CGFloat = 30
    private let footerText: String = {
        var text = "Version: 1.0\n"
        text += "Credits: OpenSSL / ZipZap\n"
        text += "Made with ♥ by Fourplex Labs"
        return text
    }()

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: self.view.frame, style: .Grouped)
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "HomeCell")
        tableView.separatorStyle = .None
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

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .Default, reuseIdentifier: nil)
        let font = UIFont.systemFontOfSize(20)
        if indexPath.section == 0 {
            cell.textLabel?.font = font
            cell.textLabel?.text = "How to use it"
        } else {
            let label = UILabel()
            label.textColor = self.view.tintColor
            label.font = font
            label.text = "Open Safari"
            label.sizeToFit()
            label.fp_x = (tableView.fp_width - label.fp_width) / 2
            label.fp_y = (cellHeight - label.fp_height) / 2
            cell.addSubview(label)
        }
        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 0 {
            self.showTutorial()
        } else {
            UIApplication.sharedApplication().openURL(NSURL(string: "https://www.apple.com")!)
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
        if section == 0 {
            label.text = HomeSection.Tutorial.rawValue.uppercaseString
        } else {
            label.text = HomeSection.Safari.rawValue.uppercaseString
        }
        label.sizeToFit(); label.fp_x = sectionLeftPadding; label.fp_y = sectionTopPadding
        view.addSubview(label)
        return view
    }
}
