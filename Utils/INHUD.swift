//
//  INHUD.swift
//  Inspect
//
//  Created by hewig on 1/15/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

import UIKit

open class INHUD: UIView {

    static let sharedHUD = INHUD()
    open var contentView: UIView? {
        willSet {
            self.contentView?.removeFromSuperview()
        }
        didSet {
            guard let contentView = self.contentView else {
                return
            }
            do {
                try ObjC.catchException {
                    self.backgroundView.contentView.addSubview(contentView)
                }
            } catch {
                print("An error ocurred: \(error)")
            }
        }
    }

    fileprivate var backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .light))

    override public init(frame: CGRect) {
        super.init(frame: frame)
        finishInit()
    }

    public init() {
        super.init(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: UIScreen.main.bounds.size))
        finishInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        finishInit()
    }

    open func showInView(_ view: UIView) {
        view.addSubview(self.backgroundView)
        backgroundView.center = view.center
    }

    open func hide() {
        backgroundView.removeFromSuperview()
    }

    fileprivate func finishInit() {

        self.autoresizingMask = [.flexibleWidth, .flexibleWidth]
        backgroundView.frame = CGRect(x: 0, y: 0, width: 265, height: 90)
        backgroundView.backgroundColor = UIColor(white:0.0, alpha:0.15)
        backgroundView.layer.cornerRadius = 9.0
        backgroundView.layer.masksToBounds = true

        let offset = 20.0

        let motionEffectsX = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        motionEffectsX.maximumRelativeValue = offset
        motionEffectsX.minimumRelativeValue = -offset

        let motionEffectsY = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        motionEffectsY.maximumRelativeValue = offset
        motionEffectsY.minimumRelativeValue = -offset

        let group = UIMotionEffectGroup()
        group.motionEffects = [motionEffectsX, motionEffectsY]
        backgroundView.addMotionEffect(group)
        backgroundView.center = self.center

        NotificationCenter.default.addObserver(self, selector: #selector(orientationDidChange(notification:)), name: Notification.Name.UIDeviceOrientationDidChange, object: nil)
    }

    @objc func orientationDidChange(notification: Notification) {
        self.frame = UIScreen.main.bounds
        self.backgroundView.center = self.center
        self.backgroundView.setNeedsDisplay()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

open class INHUDTextView: UIView {

    open let label: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.boldSystemFont(ofSize: 17.0)
        label.textColor = UIColor.black.withAlphaComponent(0.85)
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

    override open func layoutSubviews() {
        super.layoutSubviews()
        let padding: CGFloat = 10.0
        self.label.frame = bounds.insetBy(dx: padding, dy: padding)
    }

    fileprivate func finishInit(_ text: String?) {
        self.label.text = text
        self.addSubview(self.label)
    }
}
