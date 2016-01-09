//
//  X509.swift
//  Inspect
//
//  Created by hewig on 1/3/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import Foundation

typealias cX509 = X509Certificate;

public struct X509Certificate {
    
    public var subjectName = ""
    
    public var subjectDict: [String: AnyObject] {
        get {
            return self.subjectName.x509Entries()
        }
    }
    
    public var issuerDict: [String: AnyObject] {
        get {
            return self.issuerName.x509Entries()
        }
    }
    
    public var issuerName = ""
    public var fingerprint = ""
    public var version = 1
    public var serialNumber = 0
    public var signature = ""
    public var signatureAlgorithm = ""
    
    // hex string
    public var pubKey = ""
    
    public var notValidBefore = ""
    public var notValidAfter = ""
    public var isCA = false
    public var isSelfSigned = false
    public var extensions: [[String: String]] = []
    
    //others
    public var keyUsage = ""
    public var subjectKeyId = ""
    public var authorityKeyId = ""
    public var netscapeCertType = ""
    
    init(certificate: SecCertificate) {
        
        let data = SecCertificateCopyData(certificate) as NSData
        var bytes = UnsafePointer<UInt8>(data.bytes)
        let cert = d2i_X509(nil, &bytes, data.length)

        self.subjectName = cX509.getSubject(cert)
        self.issuerName = cX509.getIssuer(cert)
        self.version = ASN1_INTEGER_get(cert.memory.cert_info.memory.version) + 1
        self.serialNumber = ASN1_INTEGER_get(X509_get_serialNumber(cert))
        
        let pkey_nid = OBJ_obj2nid(cert.memory.cert_info.memory.key.memory.algor.memory.algorithm)
        self.signatureAlgorithm = String.fromCString(OBJ_nid2ln(pkey_nid))!
        
        let pkey = X509_get_pubkey(cert)
        self.pubKey = cX509.pubKeyDigest(pkey, nid: pkey_nid)

        self.notValidBefore = cX509.getNotBefore(cert)
        self.notValidAfter = cX509.getNotAfter(cert)
        self.isCA = X509_check_ca(cert) >= 1
        
        defer {
            EVP_PKEY_free(pkey)
            X509_free(cert)
        }
    }
    
    func description() -> String {
        var description = "X509Certificate: {\n"
        description += "\t subject = \(self.subjectName)\n"
        description += "\t issuer = \(self.issuerName)\n"
        description += "\t version = \(self.version)\n"
        description += "\t serial number = \(self.serialNumber)\n"
        description += "\t signature algorithm = \(self.signatureAlgorithm)\n"
        description += "\t not valid before = \(self.notValidBefore)\n"
        description += "\t not valid after = \(self.notValidAfter)\n"
        description += "\t is CA = \(self.isCA)\n"
        description += "}\n"
        return description
    }
}

extension String {
    func x509Entries() -> [String: AnyObject] {
        var dict = [String: AnyObject]()
        let componments = self.characters.split("/").map(String.init)
        for componment in componments {
            let tuples = componment.characters.split("=").map(String.init)
            dict[tuples[0]] = tuples[1]
        }
        return dict
    }
}

extension X509Certificate {
    
    static func getSubject(cert: UnsafeMutablePointer<x509_st>) -> String {
        let subject = X509_get_subject_name(cert)
        return String.fromCString(X509_NAME_oneline(subject, nil, 0))!
    }
    
    static func getIssuer(cert: UnsafeMutablePointer<x509_st>) -> String {
        let issuer = X509_get_issuer_name(cert)
        return String.fromCString(X509_NAME_oneline(issuer, nil, 0))!
    }
    
    static func asn1TimeToString(time: UnsafePointer<ASN1_TIME>) -> String {
        let bio = BIO_new(BIO_s_mem())
        defer {
            BIO_free(bio)
        }
        if ASN1_TIME_print(bio, time) > 0 {
            let buffer = UnsafeMutablePointer<Int8>.alloc(128)
            defer {
                buffer.destroy()
            }
            if BIO_gets(bio, buffer, 128) > 0 {
                return String.fromCString(buffer)!
            }
        }
        
        return ""
    }
    
    static func getNotBefore(cert: UnsafePointer<x509_st>) -> String {
        let time = cert.memory.cert_info.memory.validity.memory.notBefore
        return self.asn1TimeToString(time)
    }
    
    static func getNotAfter(cert: UnsafePointer<x509_st>) -> String {
        let time = cert.memory.cert_info.memory.validity.memory.notAfter
        return self.asn1TimeToString(time)
    }
    
    static func pubKeyDigest(pubKey: UnsafePointer<EVP_PKEY>, nid: Int32) -> String {
        var hexString = ""
        switch nid {
        case NID_rsaEncryption:
            hexString = "//todo rsa"
            break
        case NID_dsa:
            hexString = "//todo dsa"
            break
        default: break
        }
        return hexString
    }
}