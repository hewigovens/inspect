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
    case KeyUsage = "Key Usage"
    case Misc = "Misc"
}

extension String {
    
    static let x509EntryMapper: [String: String] = [
        "UID": "User ID",
        "CN": "Common Name",
        "OU": "Organization Unit",
        "ST": "State/Province",
        "O": "Organization",
        "C": "Country",
        "L": "Locality",
        "businessCategory": "Business Category",
        "street": "Street Address",
        "jurisdictionST": "Inc. State/Province",
        "jurisdictionC": "Inc. Country",
        "postalCode": "Postal Code",
        "serialNumber": "Serial Number"
    ]
    
    func x509Entries() -> [(String, AnyObject)] {
        var array: [(String, AnyObject)] = []
        let componments = self.characters.split("/").map(String.init)
        for componment in componments {
            let tuples = componment.characters.split("=").map(String.init)
            if tuples.count == 2 {
                let rawKey = tuples[0]
                if let entry = String.x509EntryMapper[rawKey] {
                    array.append((entry, tuples[1]))
                } else {
                    array.append((rawKey, tuples[1]))
                }
            } else {
                print("!!!error parsing \(self)")
                continue
            }
        }
        return array
    }
    
    func fingerprintRepresentation() -> String {
        var array: [String] = []
        var hex = ""
        for (index, char) in self.characters.enumerate() {
            hex.append(char)
            if (index + 1) % 2 == 0 {
                array.append(hex)
                hex = ""
            }
        }
        return array.joinWithSeparator(" ")
    }
}

extension X509Certificate {
    
    public var issuerDict: [(String, AnyObject)] {
        get {
            return self.issuerName.x509Entries()
        }
    }
    
    public var subjectDict: [(String, AnyObject)] {
        get {
            return self.subjectName.x509Entries()
        }
    }
    
    public func displaySections() -> ([[(String, AnyObject)]], [CertificateInfoSection]) {
        var sectionDatas: [[(String, AnyObject)]] = []
        var sectionNames: [CertificateInfoSection] = []
        
        sectionNames.append(.Subject)
        sectionDatas.append(self.subjectDict)

        sectionNames.append(.Issuer)
        sectionDatas.append(self.issuerDict)
        
        sectionNames.append(.Misc)
        sectionDatas.append([
            ("Version", String(self.version)),
            ("Serial Number", self.serialNumber.fingerprintRepresentation()),
            ("Not Valid Before", self.notValidBefore),
            ("Not Valid After", self.notValidAfter),
        ])
        
        sectionNames.append(.Algorithm)
        var datas: [(String, AnyObject)] = [
            ("Signature Algorithm", self.signatureAlgorithm),
            ("Pub Key Algorithm", self.pubKeyAlgorithm),
            ("Pub Key Size", String(self.pubKeySize)),
        ]
        if self.pubKeyECCurveName.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0 {
            datas.append(("ECCurve Name", self.pubKeyECCurveName))
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
        
        if self.subjectAltNames.count > 0 {
            sectionNames.append(.SubjectAltNames)
            var datas: [(String, AnyObject)] = []
            for index in 0..<self.subjectAltNames.count {
                datas.append(("No.\(index) Alt Name", self.subjectAltNames[index]))
            }
            sectionDatas.append(datas)
        }
        
        return (sectionDatas, sectionNames)
    }
}