//
//  ViewController.swift
//  Inspect
//
//  Created by hewig on 12/28/15.
//  Copyright © 2015 fourplex. All rights reserved.
//

import UIKit

class TutorialViewController: UIViewController, UIScrollViewDelegate {

    let steps = 6
    lazy var carouselView: UIScrollView = {
        let scrollview = UIScrollView(frame: self.view.frame)
        scrollview.bounces = false
        scrollview.pagingEnabled = true
        scrollview.delegate = self
        scrollview.showsHorizontalScrollIndicator = false
        scrollview.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        return scrollview
    }()

    lazy var indicator: UIPageControl = {
        let size: CGFloat = 36
        let width = (self.view.fp_width - 54) / 2
        let indicator = UIPageControl(frame: CGRect(x: (self.view.fp_width - width) / 2, y: 30, width: width, height: size))
        indicator.numberOfPages = self.steps
        indicator.pageIndicatorTintColor = UIColor.whiteColor()
        indicator.currentPageIndicatorTintColor = UIColor(red:0.44, green:0.51, blue:0.84, alpha:1.00)
        indicator.addTarget(self, action: #selector(changePage), forControlEvents: .ValueChanged)
        return indicator
    }()

    lazy var closeButton: UIButton = {
        let button = UIButton(type: .System)
        button.setTitle("×", forState: .Normal)
        button.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        button.setTitleColor(UIColor.lightGrayColor(), forState: .Highlighted)
        button.titleLabel?.font = UIFont.systemFontOfSize(40)
        button.addTarget(self, action: #selector(closeAction), forControlEvents: .TouchUpInside)
        button.frame = CGRect(x: 10, y: 20, width: 44, height: 44)
        return button
    }()

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        NSUserDefaults.standardUserDefaults().setBool(false, forKey: kFirstRun)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.blackColor()
        self.automaticallyAdjustsScrollViewInsets = false
        self.configureSubviews()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.carouselView.contentSize = CGSize(width: self.view.fp_width * 6, height: self.view.fp_height)
    }

    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        self.indicator.currentPage = Int(scrollView.contentOffset.x / scrollView.fp_width)
    }
}

extension TutorialViewController {
    @objc func closeAction() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    @objc func changePage() {
        let page = self.indicator.currentPage
        var frame = self.carouselView.frame
        frame.origin.x = frame.size.width * CGFloat(page)
        frame.origin.y = 0
        self.carouselView.scrollRectToVisible(frame, animated: true)
    }

    private func configureSubviews() {
        var offset: CGFloat = 0
        let leftPadding: CGFloat = 10
        let topPadding: CGFloat = 80
        for i in 1...steps {
            let containerView = UIView(frame: CGRect(x: offset + leftPadding, y: topPadding, width: carouselView.fp_width - 2 * leftPadding, height: carouselView.fp_height - topPadding - 2 * leftPadding))
            containerView.layer.cornerRadius = 12
            containerView.backgroundColor = UIColor(red:0.44, green:0.51, blue:0.84, alpha:1.00)

            let imageView = UIImageView(image: UIImage(named: "step\(i)"))
            imageView.frame = CGRect(x: 0, y: topPadding / 2, width: containerView.fp_width, height: containerView.fp_height - topPadding / 2)
            imageView.clipsToBounds = true
            imageView.contentMode = .ScaleAspectFit

            let label = UILabel(frame: CGRect.zero)
            label.text = titleForStep(i)
            label.textColor = UIColor.whiteColor()
            label.sizeToFit()
            label.frame = CGRect(x: (containerView.fp_width - label.fp_width) / 2, y: 10, width: label.fp_width, height: label.fp_height)
            containerView.addSubview(label)
            containerView.addSubview(imageView)

            self.carouselView.addSubview(containerView)

            offset += carouselView.fp_width
        }

        self.view.addSubview(self.carouselView)
        self.view.addSubview(self.indicator)
        self.view.addSubview(self.closeButton)
    }

    private func titleForStep(step: Int) -> String {
        switch step {
        case 1: return "Step \(step): Tap Action Button"
        case 2: return "Step \(step): Tap More Button"
        case 3: return "Step \(step): Enable Certificate"
        case 4: return "Step \(step): Tap Certificate Button"
        case 5: return "Step \(step): Tap Share for more options"
        case 6: return "Step \(step): Export or Feedback :)"
        default: return ""
        }
    }
}
