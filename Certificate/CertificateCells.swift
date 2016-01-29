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
    
    public var trustResult: SecTrustResultType = UInt32(kSecTrustResultUnspecified) {
        didSet {
            if trustResult == UInt32(kSecTrustResultProceed) ||
               trustResult == UInt32(kSecTrustResultUnspecified) {
                return
            }
            
            self.suffix = "_Invalid"
        }
    }
    public var level = 0 {
        didSet {
            if self.level == 0 {
                self.iconView?.image = UIImage(imageLiteral: "CertSmallRoot" + suffix)
            } else {
                self.indicatorLeading?.constant = (self.indicatorLeading?.constant)! - CGFloat(self.level) * 35.0
                self.iconView?.image = UIImage(imageLiteral: "CertSmallStd" + suffix)
            }
        }
    }
    public var name = "" {
        didSet {
            self.titleLabel?.text = self.name
            self.titleLabel?.numberOfLines = 0
        }
    }
    
    private var suffix = ""
}

// MARK: CertificateInfoCell used in Content View

public class CertificateInfoCell: UITableViewCell {
    static let reuseId = "kCertificateInfoCell"
    
    @IBOutlet public weak var titleLabel: UILabel!
    @IBOutlet public weak var detailLabel: UILabel!
}

public class CertificateInfoCell2: UITableViewCell {
    static let reuseId = "kCertificateInfoCell2"
    
    @IBOutlet public weak var titleLabel: UILabel!
    @IBOutlet public weak var longTextLabel: UILabel!
}

public enum CertificateInfoSection: String {
    case Subject = "Subject Name"
    case Issuer = "Issuer Name"
    case Algorithm = "Algorithm"
    case PubKeyInfo = "Public Key Info"
    case Signature = "Signature"
    case Fingerprints = "Fingerprints"
    case SubjectAltNames = "Subject Alt Names"
    case Extensions = "Extensions"
    case Misc = "Misc"
}

extension X509Certificate {
    public func displaySections() -> ([[(String, AnyObject)]], [CertificateInfoSection]) {
        var sectionDatas: [[(String, AnyObject)]] = []
        var sectionNames: [CertificateInfoSection] = []
        
        sectionNames.append(.Subject)
        sectionDatas.append(self.subjectTuples)

        sectionNames.append(.Issuer)
        sectionDatas.append(self.issuerTuples)
        
        sectionNames.append(.Misc)
        sectionDatas.append([
            ("Serial Number", self.serialNumber.fingerprintRepresentation()),
            ("Version", String(self.version)),
            ("Not Valid Before", self.notValidBefore),
            ("Not Valid After", self.notValidAfter),
        ])
        
        sectionNames.append(.Algorithm)
        var datas: [(String, AnyObject)] = [
            ("Signature Algorithm", self.signatureAlgorithm),
            ("Pub Key Algorithm", String.x509EntryMapper[self.pubKeyAlgorithm] ?? self.pubKeyAlgorithm),
            ("Pub Key Size", String(self.pubKeySize)),
        ]
        if self.pubKeyECCurveName.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0 {
            datas.append(("Elliptic Curve Name", self.pubKeyECCurveName.capitalizedString))
        }
        sectionDatas.append(datas)

        sectionNames.append(.Signature)
        sectionDatas.append([
            ("Signature", self.signature.fingerprintRepresentation()),
        ])
        
        sectionNames.append(.PubKeyInfo)
        sectionDatas.append([
            ("Pub Key", self.pubKey.fingerprintRepresentation()),
        ])

        sectionNames.append(.Fingerprints)
        sectionDatas.append([
            ("md5", self.md5.fingerprintRepresentation()),
            ("sha1", self.sha1.fingerprintRepresentation())
        ])
        
        if self.extensions.count > 0 {
            sectionNames.append(.Extensions)
            sectionDatas.append(self.extensions)
        }
        
        if self.subjectAltNames.count > 0 {
            sectionNames.append(.SubjectAltNames)
            sectionDatas.append(self.subjectAltNames)
        }
        
        return (sectionDatas, sectionNames)
    }
}