//
//  FAK+Utils.swift
//  AnyTime
//
//  Created by Tao Xu on 9/28/17.
//  Copyright © 2017 Tao Xu. All rights reserved.
//

import Foundation
import FontAwesomeKit

extension FAKIcon {
    class func image(with identifier: String, size: Int = 22) -> UIImage? {
        let icon = try? self.init(identifier: identifier, size: CGFloat(size))
        return icon?.image(with: CGSize(width: size, height: size))
    }
}
