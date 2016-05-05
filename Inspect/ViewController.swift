//
//  ViewController.swift
//  Inspect
//
//  Created by hewig on 12/28/15.
//  Copyright © 2015 fourplex. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIScrollViewDelegate {

    let steps = 6
    lazy var carouselView: UIScrollView = {
        let scrollview = UIScrollView(frame: self.view.bounds)
        scrollview.bounces = false
        scrollview.pagingEnabled = true
        scrollview.delegate = self
        scrollview.showsHorizontalScrollIndicator = false
        scrollview.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        return scrollview
    }()

    lazy var indicator: UIPageControl = {
        let size: CGFloat = 8
        let width = size * CGFloat(self.steps)
        let indicator = UIPageControl(frame: CGRect(x: (self.view.fp_width - width) / 2, y: 20, width: width, height: size))
        indicator.numberOfPages = self.steps
        indicator.pageIndicatorTintColor = UIColor.whiteColor()
        indicator.currentPageIndicatorTintColor = UIColor(red:0.44, green:0.51, blue:0.84, alpha:1.00)
        return indicator
    }()

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.whiteColor()
        self.navigationController?.navigationBarHidden = true
        self.view.backgroundColor = UIColor.blackColor()

        self.automaticallyAdjustsScrollViewInsets = false
        self.configureSubviews()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didBecomeActive), name: UIApplicationDidBecomeActiveNotification, object: nil)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.carouselView.contentSize = CGSize(width: self.view.fp_width * 6, height: self.view.fp_height)
    }

    func didBecomeActive(notification: NSNotification) {
        guard let pasted = UIPasteboard.generalPasteboard().string else {return}
        guard let url = NSURL(string: pasted) where url.scheme == "https" else {return}
        self.inspectURL(url)
    }

    //MARK: UIScrollViewDelegate
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        self.indicator.currentPage = Int(scrollView.contentOffset.x / scrollView.fp_width)
    }
}

extension ViewController {
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
            label.text = "Step \(i). Tap Action Icon"
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
    }
}

extension UIViewController {
    private func inspectURL(url: NSURL) {
        let alert = UIAlertController(title: "", message: "Do you want to Inspect \(url.absoluteString) ?", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Next Time", style: .Default, handler: nil))
        alert.addAction(UIAlertAction(title: "Sure", style: .Default, handler: { _ in
            let board = UIStoryboard(name: "MainInterface", bundle: NSBundle.mainBundle())
            guard let vc = board.instantiateViewControllerWithIdentifier("ActionViewController") as? ActionViewController else {return}
            vc.URL = url
            dispatch_async(dispatch_get_main_queue(), {
                self.presentViewController(vc, animated: true, completion: nil)
            })
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }
}
