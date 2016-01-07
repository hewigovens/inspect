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
    public var issuerName = ""
    public var fingerprint = ""
    public var version = 1
    public var serialNumber = 0
    public var signature = ""
    public var signatureAlgorithm = ""
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
        
        let subject = X509_get_subject_name(cert)
        let issuer = X509_get_issuer_name(cert)
        
        self.version = ASN1_INTEGER_get(cert.memory.cert_info.memory.version) + 1
//        self.serialNumber = ASN1_INTEGER_get(cert)
        self.subjectName = String.fromCString(X509_NAME_oneline(subject, nil, 0))!
        self.issuerName = String.fromCString(X509_NAME_oneline(issuer, nil, 0))!
        

        print("==> subject \(self.subjectName)")
        print("==> issuer \(self.issuerName)")
        print("==> version \(self.version)")
        
        X509_free(cert)
    }
}