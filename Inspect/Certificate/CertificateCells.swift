//
//  CertificateCell.swift
//  Inspect
//
//  Created by hewig on 1/3/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit

// MARK: CertificateStackCell used in header view
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

// MARK: CertificateInfoCell used in Content View

public class CertificateInfoCell: UITableViewCell {
    static let reuseId = "kCertificateInfoCell"
    static let sectionsCount = 2
    
    @IBOutlet public weak var titleLabel: UILabel!
    @IBOutlet public weak var detailLabel: UILabel!
}

public enum CertificateInfoSection: String {
    case Subject = "Subject Name"
    case Issuer = "Issuer Name"
    case SignatureAlgorithm = "Signature Algorithm"
    case PubKeyInfo = "Public Key Info"
    case Fingerprints = "Fingerprints"
    case Extension = "Extended Key Usage"
    
    // todo
    case AuthorityKeyId = "Authority Key Identifier"
    case NetscapeCertificateType = "Netscape Certificate Type"
    case KeyUsage = "Key Usage"
}

extension String {
    
    static let x509EntryMapper: [String: String] = [
        "UID": "User ID",
        "CN": "Common Name",
        "OU": "Organization Unit",
        "O": "Organization",
        "C": "Country"
    ]
    
    func x509Entries() -> [String: AnyObject] {
        var dict = [String: AnyObject]()
        let componments = self.characters.split("/").map(String.init)
        for componment in componments {
            let tuples = componment.characters.split("=").map(String.init)
            let rawKey = tuples[0]
            if let entry = String.x509EntryMapper[rawKey] {
                dict[entry] = tuples[1]
            } else {
                dict[rawKey] = tuples[1]
            }
        }
        return dict
    }
}

extension X509Certificate {
    
    public var issuerDict: [String: AnyObject] {
        get {
            return self.issuerName.x509Entries()
        }
    }
    
    public var subjectDict: [String: AnyObject] {
        get {
            return self.subjectName.x509Entries()
        }
    }
    
    public func displaySections() -> ([[String: AnyObject]], [CertificateInfoSection]) {
        var sectionDatas: [[String: AnyObject]] = []
        var sectionNames: [CertificateInfoSection] = []
        
        sectionNames.append(.Subject)
        sectionDatas.append(self.subjectDict)
        
        sectionNames.append(.Issuer)
        sectionDatas.append(self.issuerDict)
       
        sectionNames.append(.Fingerprints)
        sectionDatas.append(["MD5": self.md5Fingerprint, "SHA1": self.sha1Fingerprint])
        
        return (sectionDatas, sectionNames)
    }
}