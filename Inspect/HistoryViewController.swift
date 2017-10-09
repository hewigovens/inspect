//
//  HistoryViewController.swift
//  Inspect
//
//  Created by Tao Xu on 10/7/17.
//  Copyright © 2017 fourplex. All rights reserved.
//

import UIKit
import FontAwesomeKit
import Reusable
import Kingfisher

class HistoryCell: UITableViewCell, Reusable {
    override func layoutSubviews() {
        super.layoutSubviews()
    }
}

class HistoryViewController: UITableViewController {

    var data = [String]()

    lazy var empty: UIView = {
        let view = UIView()
        let label = UILabel()
        label.text = "No Records"
        label.sizeToFit()
        label.textColor = UIColor(white: 0.25, alpha: 1)
        label.embedded(in: view, make: { make in
            make.center.equalToSuperview()
        })
        view.isHidden = true
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureData()
        configureNaviItems()
        configureSubviews()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.empty.isHidden = data.count > 0
        return data.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: HistoryCell = tableView.dequeueReusableCell(for: indexPath)
        cell.textLabel?.text = data[indexPath.row]
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15)
        cell.textLabel?.textColor = UIColor(white: 0.25, alpha: 1)
        if var url = URL(string: "https://\(data[indexPath.row])") {
            url.appendPathComponent("apple-touch-icon.png")
            cell.imageView?.contentMode = .scaleAspectFit
            cell.imageView?.kf.setImage(with: url, placeholder: FAKIonIcons.image(with: "ion-images", size: 180))
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = data[indexPath.row]
        guard let url = URL(string: "https://" + item) else { return }
        guard let vc = ActionViewController.create(url: url) else { return }
        vc.openURLAction = { url in
            if UIApplication.shared.canOpenURL(url as URL) {
                UIApplication.shared.openURL(url as URL)
            }
        }
        self.present(vc, animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .destructive, title: "Remove", handler: { _, _ in
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            UserDefaults.delete(host: self.data[indexPath.row])
            self.data.remove(at: indexPath.row)
            tableView.endUpdates()
        })
        return [delete]
    }
}

extension HistoryViewController {
    func configureData() {
        guard let defaults = UserDefaults.init(suiteName: kInspectGroupId) else { return }
        guard let hosts = defaults.stringArray(forKey: kHistoryKey) else { return }
        self.data = hosts
    }

    func configureSubviews() {
        self.tableView.register(cellType: HistoryCell.self)
        self.tableView.backgroundColor = UIColor.fp.background
        self.tableView.tableFooterView = UIView()
        self.empty.embedded(in: self.tableView, make: {
            $0.center.equalToSuperview()
        })
    }

    func configureNaviItems() {
        self.title = "Recently Lookup"
        let image = FAKIonIcons.image(with: "ion-ios-close-empty", size: 30)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(close))
    }

    @objc func close() {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
}
