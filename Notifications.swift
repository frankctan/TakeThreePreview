//
//  Notifications.swift
//  SwiftCamera
//
//  Created by Frank Tan on 7/22/17.
//  Copyright © 2017 franktan. All rights reserved.
//

import Foundation

protocol Notifications: class {
    /**
     Implementing object must retain its own label. No label attributes need be modified by
     the implementing object. Frame, text, font, alpha, etc. are all managed through
     `animateStatusView`.
     */
    var label: UILabel! { get set }

    /**
     Implementing object must initialize this variable to `false`. `Notifications` uses
     `isStatusAnimating` to track `label` state.
     */
    var isStatusAnimating: Bool { get set }

    /**
     A default implementation is provided. Implementing object need only call this method to show
     the notification label when appropriate.
     
     - parameter msg: What should the notification tell the user?
     - parameter viewController: Which `UIViewController`'s view is presenting the notification 
     `label`?
     - parameter animateFor: How long is the animation duration?
     - parameter displayFor: How long should the notification be displayed on-screen? `nil` will
     display the notification indefinitely.
     */
    func animateStatusView(_ msg: String,
                           viewController vc: UIViewController,
                           animateFor aTime: TimeInterval?,
                           displayFor time: TimeInterval?)

    /**
     A default implementation is provided. Implementing object need only call this method to hide
     the notification label.
     
     - parameter delay: How long should the dismissal animation be delayed? A `delay` of 0 will immediately hide the notification.
     - parameter completion: Completion block after dismissal animation completes.
     */
    func hideLabel(withDelay delay: TimeInterval?, completion: (() ->Void)?)
}

extension Notifications {
    func animateStatusView(_ msg: String,
                           viewController vc: UIViewController,
                           animateFor aTime: TimeInterval? = 0.6,
                           displayFor time: TimeInterval? = 4.0) {

        // Short-circuit if notification is currently animating.
        guard !self.isStatusAnimating else {
            return
        }
        self.isStatusAnimating = true

        let frame = CGRect(x: 30,
                           y: vc.view.bounds.height / 4 - 20,
                           width: vc.view.bounds.width - 60,
                           height: 40)

        // Set label attributes.
        let label = UILabel(frame: frame)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 5.0
        label.layer.masksToBounds = true
        label.text = msg
        label.font = label.font.withSize(20)
        label.textColor = .white
        label.alpha = 0
        label.numberOfLines = 0

        // Fit the entire contents of `msg` in the label's view.
        label.sizeToFit()

        /* 
         `sizeToFit()` messes with the label's frame. Ensure label is positioned and sized
        correctly.
         */
        label.frame.size.width = vc.view.bounds.width - 60
        label.frame.origin.x = 30
        label.frame.size.height = max(label.frame.size.height, 40.0)
        label.frame.origin.y = vc.view.bounds.height / 4 - label.frame.height / 2

        label.textAlignment = .center
        label.isUserInteractionEnabled = true

        self.label = label

        /*
         `labelView` is an empty container used to animate the label. Straight UILabel animation
         looks janky, probably because of `sizeToFit`. `labelView` is removed from the view 
         hierarchy after the animation is completed.
         */
        let labelView =
            UIView(frame: CGRect(x: 0.0,
                                 y: 0.0,
                                 width: vc.view.bounds.width,
                                 height: vc.view.bounds.height / 2))

        labelView.backgroundColor = label.backgroundColor
        labelView.alpha = 0.95
        labelView.layer.cornerRadius = 5.0
        labelView.layer.masksToBounds = true

        // Perform the notification animation.
        DispatchQueue.main.async {
            vc.view.addSubview(labelView)
            vc.view.addSubview(label)

            UIView.animate(withDuration: aTime ?? 0.6,
                           delay: 0.0,
                           usingSpringWithDamping: 0.7,
                           initialSpringVelocity: 0.3,
                           options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState],
                           animations: {

                            labelView.transform =
                                CGAffineTransform(scaleX: label.frame.width / labelView.frame.width,
                                                  y: label.frame.height / labelView.frame.height)

            }, completion: { (_) in
                UIView.animate(withDuration: 0.1,
                               delay: 0.0,
                               options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState],
                               animations: {

                                label.alpha = 0.95
                                labelView.alpha = 0.0

                }, completion: { (_) in

                    labelView.removeFromSuperview()
                    self.hideLabel(withDelay: time)
                })
            })
        }
    }

    func hideLabel(withDelay delay: TimeInterval? = 0.0, completion: (() ->Void)? = nil) {
        // Do nothing if `delay` or `label`are nil.
        guard let delay = delay else {
            self.isStatusAnimating = false
            completion?()
            return
        }

        guard let label = label else {
            self.isStatusAnimating = false
            completion?()
            return
        }

        // Fade out label and remove from superview.
        UIView.animate(withDuration: 0.2,
                       delay: delay,
                       options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState],
                       animations:{

                        label.alpha = 0.0
                        
        }, completion: { (_) in
            self.isStatusAnimating = false
            label.removeFromSuperview()
            completion?()
        })
    }
    
}
