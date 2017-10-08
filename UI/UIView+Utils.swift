//
//  UIView+Utils.swift
//  AnyTime
//
//  Created by Tao Xu on 9/27/17.
//  Copyright © 2017 Tao Xu. All rights reserved.
//

import Foundation
import SnapKit

extension UIView {
    convenience init(backgroundColor: UIColor) {
        self.init()
        self.backgroundColor = backgroundColor
    }
}

extension UIView {
    func embedded(in parent: UIView, make: ((ConstraintMaker) -> Void)? = nil) {
        parent.addSubview(self)
        if let make = make {
            self.snp.makeConstraints(make)
        } else {
            self.snp.makeConstraints { $0.edges.equalToSuperview() }
        }
    }
}
