//
//  X509.swift
//  Inspect
//
//  Created by hewig on 1/3/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import Foundation

public struct X509Certificate {

    public var subjectName = ""
    
    public var subjectDict: Dictionary<String, AnyObject> {
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
    public var md5Fingerprint = ""
    public var sha1Fingerprint = ""
    public var version = 1
    public var serialNumber = 0
    
    // todo
    public var signature = ""
    public var signatureAlgorithm = ""
    // todo
    public var signatureParameter = ""
    
    public var pubKey = ""
    
    public var notValidBefore = ""
    public var notValidAfter = ""
    public var isCA = false
    
    // todo
    public var isSelfSigned = false
    public var extensions: [[String: String]] = []
    
    public var keyUsage = ""
    public var subjectKeyId = ""
    public var authorityKeyId = ""
    public var netscapeCertType = ""
    
    private var once = dispatch_once_t()
    
    init(certificate: SecCertificate) {
        
        dispatch_once(&once) { () -> Void in
            OPENSSL_add_all_algorithms_noconf()
        }
        
        let data = SecCertificateCopyData(certificate) as NSData
        var bytes = UnsafePointer<UInt8>(data.bytes)
        let cert = d2i_X509(nil, &bytes, data.length)

        self.subjectName = X509Helper.getSubject(cert)
        self.issuerName = X509Helper.getIssuer(cert)
        self.version = ASN1_INTEGER_get(cert.memory.cert_info.memory.version) + 1
        self.serialNumber = ASN1_INTEGER_get(X509_get_serialNumber(cert))
        
        let algorithm = cert.memory.cert_info.memory.key.memory.algor
        
        let pkey_nid = OBJ_obj2nid(algorithm.memory.algorithm)
        if let s = String.fromCString(OBJ_nid2ln(pkey_nid)) {
            self.signatureAlgorithm = s
        }
        
        let parameter = algorithm.memory.parameter
        
        let pkey = X509_get_pubkey(cert)
        self.pubKey = X509Helper.hexPubKey(pkey, nid: pkey_nid)
//        self.pubKey = X509Helper.digestPubKey(cert)

        self.notValidBefore = X509Helper.getNotBefore(cert)
        self.notValidAfter = X509Helper.getNotAfter(cert)
        self.isCA = X509_check_ca(cert) >= 1
        
        self.md5Fingerprint = X509Helper.fingerprint(cert, method: "md5")
        self.sha1Fingerprint = X509Helper.fingerprint(cert, method: "sha1")
        
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
        description += "\t pubkey is = \(self.pubKey)\n"
        description += "\t md5 fingerprint = \(self.md5Fingerprint)\n"
        description += "\t sha1 fingerprint = \(self.sha1Fingerprint)\n"
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

extension X509Helper {
    
    static func getSubject(cert: UnsafeMutablePointer<x509_st>) -> String {
        let subject = X509_get_subject_name(cert)
        if let s = String.fromCString(X509_NAME_oneline(subject, nil, 0)) {
            return s
        }
        return ""
    }
    
    static func getIssuer(cert: UnsafeMutablePointer<x509_st>) -> String {
        let issuer = X509_get_issuer_name(cert)
        if let s = String.fromCString(X509_NAME_oneline(issuer, nil, 0)) {
            return s
        }
        return ""
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
    
    static func fingerprint(cert: UnsafePointer<x509_st>, method: String) -> String {
        let buffer = UnsafeMutablePointer<UInt8>.alloc(64)
        let len_ptr = UnsafeMutablePointer<UInt32>.alloc(1)
        defer {
            buffer.destroy()
            len_ptr.destroy()
        }
        
        let md = EVP_get_digestbyname(method)
        var string = ""
        if X509_digest(cert, md, buffer, len_ptr) > 0{
            let len = Int(len_ptr.memory)
            if len > 0 {
                let p = UnsafePointer<UInt8>(buffer)
                for char in UnsafeBufferPointer(start: p, count: len) {
                        string += String(format: "%02x", char)
                }
            }
        }
        return string
    }
    
//    static func digestPubKey(cert: UnsafePointer<x509_st>) -> String {
//        let pkey_nid = OBJ_obj2nid(cert.memory.cert_info.memory.key.memory.algor.memory.algorithm)
//        let method = EVP_get_digestbyname(OBJ_nid2sn(pkey_nid))
//        let buffer = UnsafeMutablePointer<UInt8>.alloc(512)
//        let len_ptr = UnsafeMutablePointer<UInt32>.alloc(1)
//        defer {
//            buffer.destroy()
//            len_ptr.destroy()
//        }
//        var string = ""
//        if X509_pubkey_digest(cert, method, buffer, len_ptr) > 0 {
//            let len = Int(len_ptr.memory)
//            if len > 0 {
//                let p = UnsafePointer<UInt8>(buffer)
//                for char in UnsafeBufferPointer(start: p, count: len) {
//                    string += String(format: "%02x", char)
//                }
//            }
//        }
//        return string
//    }
    
    static func getNotBefore(cert: UnsafePointer<x509_st>) -> String {
        let time = cert.memory.cert_info.memory.validity.memory.notBefore
        return self.asn1TimeToString(time)
    }
    
    static func getNotAfter(cert: UnsafePointer<x509_st>) -> String {
        let time = cert.memory.cert_info.memory.validity.memory.notAfter
        return self.asn1TimeToString(time)
    }
}