//
//  ExportItemSource.swift
//  Inspect
//
//  Created by hewig on 2/28/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit
import zipzap

@objc class ExportItemSource: NSObject, UIActivityItemSource {

    let certData: Data
    let targetHost: String
    let index: Int

    init(data: Data, host: String, index: Int) {
        self.certData = data
        self.targetHost = host
        self.index = index
    }

    func saveToDisk() -> URL? {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        guard let path = paths.first else {
            return nil
        }

        let fileName = "cert\(self.index).cer"
        let fileZipName = "/cert\(self.index).zip"
        let certZip = URL(fileURLWithPath: path + fileZipName)
        do {
            let archive = try ZZArchive(url: certZip, options: [ZZOpenOptionsCreateIfMissingKey: NSNumber(value: true as Bool)])
            let entry = ZZArchiveEntry(fileName: fileName, compress: true, dataBlock: { (_) -> Data? in
                return self.certData
            })
            try archive.updateEntries([entry])
            return certZip
        } catch let error {
            print("zip cert failed \(error.localizedDescription)")
            return nil
        }
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        guard let path = self.saveToDisk() else {
            return nil
        }
        return path
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return ""
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Exported certificate data for \(self.targetHost)"
    }
}
