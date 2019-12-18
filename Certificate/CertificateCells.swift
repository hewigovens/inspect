//
//  CertificateCell.swift
//  Inspect
//
//  Created by hewig on 1/3/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit
import SnapKit
import Reusable

// MARK: CertificateStackCell used in header view
open class CertificateStackCell: UITableViewCell {
    static let reuseId = "kCertificateStackCell"

    @IBOutlet open weak var indicatorLabel: UILabel!
    @IBOutlet open weak var iconView: UIImageView!
    @IBOutlet open weak var titleLabel: UILabel!
    @IBOutlet open weak var indicatorLeading: NSLayoutConstraint!

    open var isEV = false {
        didSet {
            if self.isEV {
                self.titleLabel?.textColor = UIColor(hexInt: 0x27c47a)
            }
        }
    }
    open var trustResult: SecTrustResultType = .unspecified {
        didSet {
            if trustResult == .proceed ||
               trustResult == .unspecified {
                return
            }

            self.suffix = "_Invalid"
        }
    }
    open var level = 0 {
        didSet {
            if self.level == 0 {
                self.iconView?.image = UIImage(named: "CertSmallRoot" + suffix)
            } else {
                self.indicatorLeading?.constant = (self.indicatorLeading?.constant)! - CGFloat(self.level) * 35.0
                self.iconView?.image = UIImage(named: "CertSmallStd" + suffix)
            }
        }
    }
    open var name = "" {
        didSet {
            self.titleLabel?.text = self.name
            self.titleLabel?.numberOfLines = 0
        }
    }

    fileprivate var suffix = ""

    open override func prepareForReuse() {
        self.titleLabel.textColor = self.textLabel?.textColor
    }
}

// MARK: CertificateInfoCell used in Content View

open class CertificateInfoCell: UITableViewCell, Reusable {
    static let reuseId = "kCertificateInfoCell"

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1000), for: .horizontal)
        return label
    }()

    lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor(hexInt: 0xaaaaaa)
        label.textAlignment = .right
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        titleLabel.numberOfLines = 1
        detailLabel.numberOfLines = 0

        self.contentView.addSubview(titleLabel)
        self.contentView.addSubview(detailLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(self.contentView).offset(15)
            make.centerY.equalTo(self.contentView)
        }

        detailLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(self.titleLabel.snp.trailing).offset(10).priority(1000)
            make.trailing.equalTo(self.contentView).offset(-7)
            make.top.equalTo(self.contentView).offset(10)
            make.bottom.equalTo(self.contentView).offset(-10)
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

open class CertificateInfoCell2: UITableViewCell, Reusable {
    static let reuseId = "kCertificateInfoCell2"

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        return label
    }()

    lazy var longTextLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor(hexInt: 0xaaaaaa)
        return label
    }()

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        longTextLabel.numberOfLines = 0

        self.contentView.addSubview(titleLabel)
        self.contentView.addSubview(longTextLabel)

        titleLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(self.contentView).offset(15)
            make.trailing.equalTo(self.contentView).offset(-7)
            make.top.equalTo(self.contentView).offset(10)
        }

        longTextLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(self.contentView).offset(15)
            make.trailing.equalTo(self.contentView).offset(-7)
            make.top.equalTo(self.titleLabel.snp.bottom).offset(10)
            make.bottom.equalTo(self.contentView).offset(-10)
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public enum CertificateInfoSection: String {
    case subject = "Subject Name"
    case issuer = "Issuer Name"
    case algorithm = "Algorithm"
    case pubKeyInfo = "Public Key Info"
    case signature = "Signature"
    case fingerprints = "Fingerprints"
    case subjectAltNames = "Subject Alt Names"
    case extensions = "Extensions"
    case misc = "Misc"
}

extension X509Certificate {
    public func displaySections() -> (sectionData: [[(String, AnyObject)]], sectionName: [CertificateInfoSection]) {
        var sectionDatas: [[(String, AnyObject)]] = []
        var sectionNames: [CertificateInfoSection] = []

        sectionNames.append(.subject)
        sectionDatas.append(self.subjectTuples)

        sectionNames.append(.issuer)
        sectionDatas.append(self.issuerTuples)

        sectionNames.append(.misc)
        sectionDatas.append([
            ("Serial Number", self.serialNumber.fingerprintRepresentation() as AnyObject),
            ("Version", String(self.version) as AnyObject),
            ("Not Valid Before", self.notValidBefore as AnyObject),
            ("Not Valid After", self.notValidAfter as AnyObject)
        ])

        sectionNames.append(.algorithm)
        var datas: [(String, AnyObject)] = [
            ("Signature Algorithm", self.signatureAlgorithm as AnyObject),
            ("Pub Key Algorithm", String.x509EntryMapper[self.pubKeyAlgorithm] as AnyObject? ?? self.pubKeyAlgorithm as AnyObject),
            ("Pub Key Size", String(self.pubKeySize) as AnyObject)
        ]
        if self.pubKeyECCurveName.lengthOfBytes(using: String.Encoding.utf8) > 0 {
            datas.append(("Elliptic Curve Name", self.pubKeyECCurveName.capitalized as AnyObject))
        }
        sectionDatas.append(datas)

        sectionNames.append(.signature)
        sectionDatas.append([
            ("Signature", self.signature.fingerprintRepresentation() as AnyObject)
        ])

        sectionNames.append(.pubKeyInfo)
        sectionDatas.append([
            ("Pub Key", self.pubKey.fingerprintRepresentation() as AnyObject)
        ])

        sectionNames.append(.fingerprints)
        sectionDatas.append([
            ("md5", self.md5.fingerprintRepresentation() as AnyObject),
            ("sha1", self.sha1.fingerprintRepresentation() as AnyObject)
        ])

        if self.extensions.count > 0 {
            sectionNames.append(.extensions)
            sectionDatas.append(self.extensions)
        }

        if self.subjectAltNames.count > 0 {
            sectionNames.append(.subjectAltNames)
            sectionDatas.append(self.subjectAltNames)
        }

        return (sectionDatas, sectionNames)
    }
}
