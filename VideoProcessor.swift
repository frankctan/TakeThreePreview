//
//  VideoProcessor.swift
//  SwiftCamera
//
//  Created by Frank Tan on 6/29/17.
//  Copyright © 2017 franktan. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage

protocol VideoProcessorDelegate: class {
    func videoProcessorDidReceiveNewImage(image: CIImage)
}

/**
Initialize object with  video `URL`. Set the `delegate` object to access new frames.
 
`cleanUp()` MUST be called when finished to prevent memory leaks.
 */
class VideoProcessor {
    /// Implement the delegate to receive new images from the video processor.
    weak var delegate: VideoProcessorDelegate?

    /// Pointer to the video.
    private let player: AVPlayer

    /// Timer object synced to screen refresh.
    private var displayLink: CADisplayLink!

    /// `VideoOutput` must be added to the `player` after `player` has finished `init`. Otherwise, error.
    private var didAddVideoOut = false

    /// Poll to get the pixel buffer of the `currentItem` at given time.
    private var videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: nil)

    init(url: URL) {
        self.player = AVPlayer(url: url)

        // Must set `actionAtItemEnd` to `.none` to allow trigger observer.
        self.player.actionAtItemEnd = .none
        self.displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidRefresh(link:)))

        // Set fps to prevent unnecessary calls to `displayLinkDidRefresh`.
        self.displayLink.preferredFramesPerSecond = 30

        // Add `displayLink` to run loop.
        self.displayLink.add(to: .current, forMode: .defaultRunLoopMode)

        // Loop video when done playing.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemDidReachEnd),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: self.player.currentItem)
    }

    /**
     What is the video asset's preferred orientation?
     
     - returns: `CGAffineTransform?` to rotate to correct orientation.
     */
    func getPreferredTransform() -> CGAffineTransform? {
        return self.player.currentItem?.asset.preferredTransform
    }

    // Restart video when end is reached.
    @objc func playerItemDidReachEnd(notification: Notification) {
        guard let playerItem = notification.object as? AVPlayerItem else {
            return
        }

        playerItem.seek(to: kCMTimeZero)
    }

    @objc func displayLinkDidRefresh(link: CADisplayLink) {
        guard self.player.currentItem?.status == AVPlayerItemStatus.readyToPlay else {
            print("not ready to play")
            return
        }

        // `videoOutput` must be added after everything else is initialized.
        if !self.didAddVideoOut {
            self.player.currentItem?.add(self.videoOutput)
            self.didAddVideoOut = true
            self.player.seek(to: kCMTimeZero)
            self.player.playImmediately(atRate: 1.0)
        }

        // Convert `CADisplayLink` time to `AVPlayer` time.
        let itemTime = self.videoOutput.itemTime(forHostTime: CACurrentMediaTime())

        // `videoOutput` only dispenses a pixel buffer at a given time once.
        guard self.videoOutput.hasNewPixelBuffer(forItemTime: itemTime) else {
            return
        }

        guard let pixelBuffer = self.videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) else {
            print("no more pixel buffers")
            return
        }

        let imageOut = CIImage(cvPixelBuffer: pixelBuffer)
        self.delegate?.videoProcessorDidReceiveNewImage(image: imageOut)
    }

    /**
     Calling `displayLink.invalidate` will allow `VideoProcessor` to `deinit`. Removing `displayLink`
     from the loop at any time and/or invalidating does not allow `VideoProcessor` to `deinit`.
     
     `cleanUp` MUST be called to prevent memory leaks!
     */
    func cleanUp() {
        self.delegate = nil
        self.player.pause()
        self.displayLink.invalidate()
        NotificationCenter.default.removeObserver(self,
                                                  name: .AVPlayerItemDidPlayToEndTime,
                                                  object: self.player.currentItem)
    }
}
