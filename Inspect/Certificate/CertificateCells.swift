//
//  CertificateCell.swift
//  Inspect
//
//  Created by hewig on 1/3/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit

public class CertificateStackCell: UITableViewCell {
    static let reuseId = "kCertificateStackCell"
    
    @IBOutlet public weak var indicatorLabel: UILabel!
    @IBOutlet public weak var iconView: UIImageView!
    @IBOutlet public weak var titleLabel: UILabel!
    @IBOutlet public weak var indicatorLeading: NSLayoutConstraint!
    
    public var level = 0 {
        didSet {
            if self.level == 0 {
                self.iconView?.image = UIImage(imageLiteral: "CertSmallRoot")
            } else {
                self.indicatorLeading?.constant = (self.indicatorLeading?.constant)! - CGFloat(self.level) * 35.0
                self.iconView?.image = UIImage(imageLiteral: "CertSmallStd")
            }
        }
    }
    public var name = "" {
        didSet {
            self.titleLabel?.text = self.name
            self.titleLabel?.numberOfLines = 0
        }
    }
}

public enum CertificateInfoSection: Int {
    case Subject
    case Issuer
}

public class CertificateInfoCell: UITableViewCell {
    static let reuseId = "kCertificateInfoCell"
    static let sectionsCount = 2
    
    @IBOutlet public weak var titleLabel: UILabel!
    @IBOutlet public weak var detailLabel: UILabel!
}

extension X509Certificate {
    func displaySections() -> [[String: AnyObject]] {
        var sections: [[String: AnyObject]] = []
        sections.append(self.subjectDict)
        sections.append(self.issuerDict)
        return sections
    }
}