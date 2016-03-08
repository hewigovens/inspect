//
//  INHUD.swift
//  Inspect
//
//  Created by hewig on 1/15/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit

public class INHUD: UIView {

    static let sharedHUD = INHUD()
    public var contentView: UIView? {
        willSet {
            self.contentView?.removeFromSuperview()
        }
        didSet {
            if self.contentView != nil {
                self.backgroundView.addSubview(self.contentView!)
            }
        }
    }

    private var backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .Light))

    override public init(frame: CGRect) {
        super.init(frame: frame)
        finishInit()
    }

    public init() {
        super.init(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: UIScreen.mainScreen().bounds.size))
        finishInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        finishInit()
    }

    public func showInView(view: UIView) {
        view.addSubview(self.backgroundView)
        backgroundView.center = view.center
    }

    public func hide() {
        backgroundView.removeFromSuperview()
    }

    private func finishInit() {
        backgroundView.frame = CGRect(x: 0, y: 0, width: 265, height: 90)
        backgroundView.backgroundColor = UIColor(white:0.0, alpha:0.15)
        backgroundView.layer.cornerRadius = 9.0
        backgroundView.layer.masksToBounds = true

        let offset = 20.0

        let motionEffectsX = UIInterpolatingMotionEffect(keyPath: "center.x", type: .TiltAlongHorizontalAxis)
        motionEffectsX.maximumRelativeValue = offset
        motionEffectsX.minimumRelativeValue = -offset

        let motionEffectsY = UIInterpolatingMotionEffect(keyPath: "center.y", type: .TiltAlongVerticalAxis)
        motionEffectsY.maximumRelativeValue = offset
        motionEffectsY.minimumRelativeValue = -offset

        let group = UIMotionEffectGroup()
        group.motionEffects = [motionEffectsX, motionEffectsY]
        backgroundView.addMotionEffect(group)
        backgroundView.center = self.center
    }
}

public class INHUDTextView: UIView {

    public let label: UILabel = {
        let label = UILabel()
        label.textAlignment = .Center
        label.font = UIFont.boldSystemFontOfSize(17.0)
        label.textColor = UIColor.blackColor().colorWithAlphaComponent(0.85)
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 3
        return label
    }()

    public init(text: String) {
        super.init(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 265.0, height: 90.0)))
        finishInit(text)
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        finishInit("")
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        finishInit("")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let padding: CGFloat = 10.0
        self.label.frame = CGRectInset(bounds, padding, padding)
    }

    private func finishInit(text: String?) {
        self.label.text = text
        self.addSubview(self.label)
    }
}
