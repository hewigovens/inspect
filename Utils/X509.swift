//
//  X509.swift
//  Inspect
//
//  Created by hewig on 1/3/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import Foundation

public struct X509Certificate {
    private lazy var __once: () = { () -> Void in
            OPENSSL_add_all_algorithms_noconf()
            OpenSSL_add_all_digests()
            OpenSSL_add_all_ciphers()
        }()
    public var subjectTuples: [(String, AnyObject)] = []
    public var issuerTuples: [(String, AnyObject)] = []

    // todo
    public var subjectName: String {
        get {
            return ""
        }
    }

    public var issuerName: String {
        get {
            return ""
        }
    }

    public var md5 = ""
    public var sha1 = ""
    public var version = 1
    public var serialNumber = ""

    public var signature = ""
    public var signatureAlgorithm = ""

    public var pubKey = ""
    public var pubKeySize = -1
    public var pubKeyAlgorithm = ""
    public var pubKeyECCurveName = ""

    public var notValidBefore = ""
    public var notValidAfter = ""
    public var isCA = false

    public var subjectAltNames: [(String, AnyObject)] = []
    public var extensions: [(String, AnyObject)] = []

    fileprivate var once = Int()

    init(certificate: SecCertificate) {

        _ = self.__once

        let data = SecCertificateCopyData(certificate) as Data
        var bytes: UnsafePointer<UInt8>? = (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count)
        guard let cert = d2i_X509(nil, &bytes, data.count) else {
            fatalError("d2i_X509 failed!")
        }


        let subjectDict = X509Helper.subject(ofCert: cert)
        self.subjectTuples = dictToTupleArray(subjectDict)

        let issuerDict = X509Helper.issuer(ofCert: cert)
        self.issuerTuples = dictToTupleArray(issuerDict)

        self.version = ASN1_INTEGER_get(cert.pointee.cert_info.pointee.version) + 1
        let serial = ASN1_INTEGER_to_BN(X509_get_serialNumber(cert), nil)
        self.serialNumber = String(validatingUTF8: BN_bn2hex(serial))!.lowercased()

        let cert_nid = OBJ_obj2nid(cert.pointee.sig_alg.pointee.algorithm)
        if let s = String(validatingUTF8: OBJ_nid2sn(cert_nid)) {
            self.signatureAlgorithm = s
        }

        self.signature = X509Helper.signatureOfCert(cert).lowercased()
        guard let pkey = X509_get_pubkey(cert) else {
            fatalError("X509_get_pubkey failed!")
        }
        let pkey_nid = OBJ_obj2nid(cert.pointee.cert_info.pointee.key.pointee.algor.pointee.algorithm)
        if let s = String(validatingUTF8: OBJ_nid2ln(pkey_nid)) {
            self.pubKeyAlgorithm = s
        }
        self.pubKey = X509Helper.hexPubKey(pkey)
        self.pubKeySize = X509Helper.size(ofPubKey: pkey)
        self.pubKeyECCurveName = X509Helper.ecCurveName(ofPubKey: pkey)

        let generalNames = X509Helper.subjectAltNames(ofCert: cert)
        for dict in generalNames {
            self.subjectAltNames.append((dict["key"] ?? "Error Key", dict["value"]! as AnyObject))
        }

        self.notValidBefore = X509Helper.getNotBefore(cert)
        self.notValidAfter = X509Helper.getNotAfter(cert)
        self.isCA = (X509_check_ca(cert) >= 1)

        self.md5 = X509Helper.x509Digest(cert, method: "md5")
        self.sha1 = X509Helper.x509Digest(cert, method: "sha1")

        let exts = X509Helper.extensions(ofCert: cert)
        for dict in exts {
            self.extensions.append((dict["key"] ?? "Error Key", dict["value"]! as AnyObject))
        }

        X509Helper.subject(ofCert: cert)
        defer {
            EVP_PKEY_free(pkey)
            X509_free(cert)
        }
    }

    fileprivate func dictToTupleArray(_ dict: [AnyHashable: Any]) -> [(String, AnyObject)] {
        var array: [(String, AnyObject)] = []
        for (obj, value) in dict {
            if let key = obj as? String {
                if let mappedKey = String.x509EntryMapper[key] {
                    array.append((mappedKey, value as AnyObject))
                } else {
                    array.append((key, value as AnyObject))
                }
            }
        }
        return array
    }
}

extension X509Certificate: CustomStringConvertible {

    public var description: String {
        var description = "X509Certificate: {\n"
        description += "\t subject = \(self.subjectName)\n"
        description += "\t issuer = \(self.issuerName)\n"
        description += "\t version = \(self.version)\n"
        description += "\t serial number = \(self.serialNumber)\n"
        description += "\t signature algorithm = \(self.signatureAlgorithm)\n"
        description += "\t not valid before = \(self.notValidBefore)\n"
        description += "\t not valid after = \(self.notValidAfter)\n"
        description += "\t is CA = \(self.isCA)\n"
        description += "\t pubkey is = \(self.pubKey)\n"
        description += "\t md5 fingerprint = \(self.md5)\n"
        description += "\t sha1 fingerprint = \(self.sha1)\n"
        description += "}\n"
        return description
    }
}

extension X509Helper {

    static func getSubject(_ cert: UnsafeMutablePointer<x509_st>) -> String {
        let subject = X509_get_subject_name(cert)
        if let s = String(validatingUTF8: X509_NAME_oneline(subject, nil, 0)) {
            return s
        }
        return ""
    }

    static func getIssuer(_ cert: UnsafeMutablePointer<x509_st>) -> String {
        let issuer = X509_get_issuer_name(cert)
        if let s = String(validatingUTF8: X509_NAME_oneline(issuer, nil, 0)) {
            return s
        }
        return ""
    }

    static func convertASN1TimeToString(_ time: UnsafePointer<ASN1_TIME>) -> String {
        let bio = BIO_new(BIO_s_mem())
        defer {
            BIO_free(bio)
        }
        if ASN1_TIME_print(bio, time) > 0 {
            var buffer = UnsafeMutablePointer<Int8>.allocate(capacity: 128)
            defer {
                buffer.deinitialize()
                buffer.deallocate(capacity: 128)
            }
            if BIO_gets(bio, buffer, 128) > 0 {

                let string = String(cString: buffer)
                let inFormatter = DateFormatter()
                inFormatter.dateFormat = "MMM dd HH:mm:ss yyyy zzz"
                if let date = inFormatter.date(from: string) {
                    return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .medium)
                } else {
                    return string
                }
            }
        }
        return ""
    }

    static func x509Digest(_ cert: UnsafePointer<x509_st>, method: String) -> String {
        var buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        var len_ptr = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        defer {
            buffer.deinitialize()
            buffer.deallocate(capacity: 64)

            len_ptr.deinitialize()
            len_ptr.deallocate(capacity: 1)
        }

        let md = EVP_get_digestbyname(method)
        var string = ""
        if X509_digest(cert, md, buffer, len_ptr) > 0 {
            let len = Int(len_ptr.pointee)
            if len > 0 {
                let p = UnsafePointer<UInt8>(buffer)
                for char in UnsafeBufferPointer(start: p, count: len) {
                        string += String(format: "%02x", char)
                }
            }
        }
        return string
    }

    static func x509PubKeyDigest(_ cert: UnsafePointer<x509_st>) -> String {

        let pkey_nid = OBJ_obj2nid(cert.pointee.sig_alg.pointee.algorithm)
        let method = EVP_get_digestbyname(OBJ_nid2ln(pkey_nid))
        var buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 256)
        var len_ptr = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        defer {
            buffer.deinitialize()
            buffer.deallocate(capacity: 256)

            len_ptr.deinitialize()
            len_ptr.deallocate(capacity: 1)
        }
        if X509_pubkey_digest(cert, method, buffer, len_ptr) > 0 {
            let p = UnsafePointer<UInt8>(buffer)
            let len = Int(len_ptr.pointee)
            var string = ""
            for char in UnsafeBufferPointer(start: p, count: len) {
                string += String(format: "%02x", char)
            }
            return string
        }

        return ""
    }

    static func getNotBefore(_ cert: UnsafePointer<x509_st>) -> String {
        let time = cert.pointee.cert_info.pointee.validity.pointee.notBefore
        return self.convertASN1TimeToString(time!)
    }

    static func getNotAfter(_ cert: UnsafePointer<x509_st>) -> String {
        let time = cert.pointee.cert_info.pointee.validity.pointee.notAfter
        return self.convertASN1TimeToString(time!)
    }

    static func signatureOfCert(_ cert: UnsafePointer<x509_st>) -> String {
        let sig = cert.pointee.signature
        let len = Int((sig?.pointee.length)!)
        let p = UnsafePointer<UInt8>(sig?.pointee.data)
        var string = ""
        for char in UnsafeBufferPointer(start: p, count: len) {
            string += String(format: "%02x", char)
        }
        return string
    }
}


//MARK: String extension for x509
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
        "jurisdictionL": "Inc. Locality",
        "postalCode": "Postal Code",
        "serialNumber": "Serial Number",
        "rsaEncryption": "RSA Encryption",
        "dsaEncryption": "DSA Encryption",
        "dhKeyAgreement": "DH Key Agreement",
        "id-ecPublicKey": "ECC Public Key"
    ]

    func x509Entries() -> [(String, AnyObject)] {
        var array: [(String, AnyObject)] = []
        let componments = self.characters.split(separator: "/").map(String.init)
        for componment in componments {
            let tuples = componment.characters.split(separator: "=").map(String.init)
            if tuples.count == 2 {
                let rawKey = tuples[0]
                if let entry = String.x509EntryMapper[rawKey] {
                    array.append((entry, tuples[1] as AnyObject))
                } else {
                    array.append((rawKey, tuples[1] as AnyObject))
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
        for (index, char) in self.characters.enumerated() {
            hex.append(char)
            if (index + 1) % 2 == 0 {
                array.append(hex)
                hex = ""
            }
        }
        return array.joined(separator: " ")
    }
}
