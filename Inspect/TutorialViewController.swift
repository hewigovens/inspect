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
    var didRotate = false
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
        self.layoutContainerView()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.setLightStatusBar()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.setDarkStatusBar()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if self.didRotate {
            self.layoutContainerView()
        }
        self.didRotate = false
    }

    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        self.didRotate = true
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

    private func layoutContainerView() {
        let size = UIScreen.mainScreen().bounds.size
        var offset: CGFloat = 0
        let leftPadding: CGFloat = 10
        let topPadding: CGFloat = 80
        for i in 1...steps {
            if let containerView = self.carouselView.viewWithTag(10 + i) {
                containerView.frame = CGRect(x: offset + leftPadding, y: topPadding, width: size.width - 2 * leftPadding, height: size.height - topPadding - 2 * leftPadding)
                if let image = self.carouselView.viewWithTag(100 + i) {
                    image.frame = CGRect(x: 0, y: topPadding / 2, width: containerView.fp_width, height: containerView.fp_height - topPadding / 2)
                    image.setNeedsLayout()
                }
                if let label = self.carouselView.viewWithTag(1000 + i) {
                    label.frame = CGRect(x: (containerView.fp_width - label.fp_width) / 2, y: 10, width: label.fp_width, height: label.fp_height)
                    label.setNeedsLayout()
                }
                view.setNeedsLayout()
            }
            offset += size.width
        }
        self.carouselView.contentSize = CGSize(width: size.width * 6, height: size.height)
        self.view.fp_size = size
        self.carouselView.fp_size = size
    }

    private func configureSubviews() {
        for i in 1...steps {
            let containerView = UIView()
            containerView.layer.cornerRadius = 12
            containerView.backgroundColor = UIColor(red:0.44, green:0.51, blue:0.84, alpha:1.00)
            containerView.tag = 10 + i

            let imageView = UIImageView(image: UIImage(named: "step\(i)"))
            imageView.clipsToBounds = true
            imageView.contentMode = .ScaleAspectFit
            imageView.tag = 100 + i

            let label = UILabel(frame: CGRect.zero)
            label.text = titleForStep(i)
            label.textColor = UIColor.whiteColor()
            label.sizeToFit()
            label.tag = 1000 + i

            containerView.addSubview(label)
            containerView.addSubview(imageView)
            self.carouselView.addSubview(containerView)
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
        case 5: return "Step \(step): View and Tap for more options"
        case 6: return "Step \(step): Scan in SSLLabs or Export"
        default: return ""
        }
    }
}
