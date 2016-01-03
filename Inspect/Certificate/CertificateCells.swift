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
    public var level = 0 {
        didSet {
            if self.level == 0 {
                self.imageView?.image = UIImage(imageLiteral: "CertSmallRoot")
            } else {
                self.imageView?.image = UIImage(imageLiteral: "CertSmallStd")
            }
        }
    }
    public var name = "" {
        didSet {
            self.textLabel?.text = self.name
            self.textLabel?.numberOfLines = 0
        }
    }
}

public class CertificateInfoCell: UITableViewCell {
    static let reuseId = "kCertificateInfoCell"
}