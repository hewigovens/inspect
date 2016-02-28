//
//  ExportItemSource.swift
//  Inspect
//
//  Created by hewig on 2/28/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit

@objc class ExportItemSource : NSObject, UIActivityItemSource {
    
    let certData: NSData
    let targetHost: String
    let index: Int
    
    init(data: NSData, host: String, index: Int) {
        self.certData = data
        self.targetHost = host
        self.index = index
    }
    
    func activityViewController(activityViewController: UIActivityViewController, itemForActivityType activityType: String) -> AnyObject? {
        
        let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
        guard let path = paths.first else {
            return nil
        }
        
        let file_name = "cert\(self.index).cer";
        let file_zip_name = "/cert\(self.index).zip"
        let cert_zip = NSURL(fileURLWithPath: path + file_zip_name);
        print(cert_zip)
        do {
            let archive = try ZZArchive(URL: cert_zip, options: [ZZOpenOptionsCreateIfMissingKey: NSNumber(bool: true)])
            let entry = ZZArchiveEntry(fileName: file_name, compress: true, dataBlock: { (_) -> NSData? in
                return self.certData;
            })
            try archive.updateEntries([entry])
            
            return cert_zip
            
        } catch (let error as NSError) {
            print("zip cert failed \(error.description)")
            return nil
        }
    }
    
    func activityViewControllerPlaceholderItem(activityViewController: UIActivityViewController) -> AnyObject {
        return ""
    }
    
    func activityViewController(activityViewController: UIActivityViewController, subjectForActivityType activityType: String?) -> String {
        return "Exported certificate data for \(self.targetHost)"
    }
}