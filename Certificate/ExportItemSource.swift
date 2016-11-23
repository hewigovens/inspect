//
//  ExportItemSource.swift
//  Inspect
//
//  Created by hewig on 2/28/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit

@objc class ExportItemSource: NSObject, UIActivityItemSource {

    let certData: Data
    let targetHost: String
    let index: Int

    init(data: Data, host: String, index: Int) {
        self.certData = data
        self.targetHost = host
        self.index = index
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivityType) -> Any? {

        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        guard let path = paths.first else {
            return nil
        }

        let file_name = "cert\(self.index).cer"
        let file_zip_name = "/cert\(self.index).zip"
        let cert_zip = URL(fileURLWithPath: path + file_zip_name)
        print(cert_zip)
        do {
            let archive = try ZZArchive(url: cert_zip, options: [ZZOpenOptionsCreateIfMissingKey: NSNumber(value: true as Bool)])
            let entry = ZZArchiveEntry(fileName: file_name, compress: true, dataBlock: { (_) -> Data? in
                return self.certData
            })
            try archive.updateEntries([entry])

            return cert_zip

        } catch (let error as NSError) {
            print("zip cert failed \(error.description)")
            return nil
        }
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return ""
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivityType?) -> String {
        return "Exported certificate data for \(self.targetHost)"
    }
}
