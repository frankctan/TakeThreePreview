//
//  VideoRecorder.swift
//  SwiftCamera
//
//  Created by Frank Tan on 6/15/17.
//  Copyright © 2017 franktan. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage
import Photos

protocol VideoRecorderDelegate: class {
    func didFinishRecording(_ sender: VideoRecorder)
}

/**
 init with resolution and desired fps to get started. Set the delegate to be notified when
 the finalized media file is available. Files are saved to iOS's `tempDir`. Files will be 
 overwritten if `start` is called more than once.
 */
class VideoRecorder {
    // Set the delegate to be notified when system has finalized the video.
    weak var delegate: VideoRecorderDelegate?

    // Nuts and bolts of the API.
    private var videoWriter: AVAssetWriter?
    private let videoWriterInput: AVAssetWriterInput
    private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor

    // Used to determine the time of the next frame.
    private let fps: Int
    private var frameNumber: Int = 0

    // Allow user to access `url` to perform further actions on the saved video.
    private(set) var url: URL

    init(with resolution: CGSize, fps: Int = 30) {

        // Initialize temporary URL.
        let tempDir = NSTemporaryDirectory() + "aMov.mov"
        self.url = URL(fileURLWithPath: tempDir)

        // If applicable, remove previous item at temporary URL so we can re-write.
        if FileManager.default.fileExists(atPath: tempDir) {
            try? FileManager.default.removeItem(at: self.url)
        }

        // Set video writer encoding and frame settings.
        let videoWriterSettings: [String : Any] =
            [AVVideoCodecKey: AVVideoCodecH264,
             AVVideoWidthKey: NSNumber(value: Float(resolution.width)),
             AVVideoHeightKey: NSNumber(value: Float(resolution.height))]

        self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo,
                                                   outputSettings: videoWriterSettings)

        self.videoWriterInput.expectsMediaDataInRealTime = true

        /* 
        32-bit ARGB is not necessarily the only or the most performant option but was the easiest
        to reason about.
        */
        let pxBufferAttributes: [String : Any] =
            [kCVPixelBufferPixelFormatTypeKey as String:
                NSNumber.init(value: kCVPixelFormatType_32ARGB)]

        self.pixelBufferAdaptor =
            AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.videoWriterInput,
                                                 sourcePixelBufferAttributes: pxBufferAttributes)

        self.fps = fps

        // This should always succeed as we're removing the previous item.
        do {
            let videoWriter = try AVAssetWriter(outputURL: self.url, fileType: AVFileTypeQuickTimeMovie)
            if videoWriter.canAdd(self.videoWriterInput) {
                videoWriter.add(self.videoWriterInput)
            } else {
                print("VideoRecorder: unable to add input")
                return
            }

            self.videoWriter = videoWriter
        } catch {
            print("unable to initialize video writer")
        }

    }

    /**
     Call when user expresses intent to start recording.
     
     MUST be called before any frames are added.
     */
    func start() {
        _ = self.videoWriter?.startWriting()
        self.videoWriter?.startSession(atSourceTime: kCMTimeZero)

    }

    /**
     Call when user expresses intent to stop recording.
     
     Video will not be accessible until `stop()` is called.
     */
    func stop() {
        self.videoWriterInput.markAsFinished()

        self.videoWriter?.finishWriting {
            self.delegate?.didFinishRecording(self)
        }
    }

    /**
     Add a frame to the movie recording. According to docs, `CIContext` initialization is expensive.
     User should store their own context and pass it in here.

     - parameter image: what is the image to be recorded?
     - parameter context: needed to render a `CIImage` into a pixel buffer.
     */
    func add(image: CIImage, in context: CIContext) {
        // Get the pool of pixel buffers.
        guard let pool = self.pixelBufferAdaptor.pixelBufferPool else {
            print("unable to initialize pixel buffer pool")
            return
        }

        // Make sure video processor is ready for more data.
        if self.videoWriterInput.isReadyForMoreMediaData {
            var buffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(nil,
                                                            pool,
                                                            &buffer)

            guard status == kCVReturnSuccess else {
                print("failed to create pxBuffer from pool")
                return
            }

            guard let pxBuffer = buffer else {
                print("pixel buffer is nil")
                return
            }

            // Render image to pxBuffer.
            context.render(image, to: pxBuffer)

            // Add pixel buffer to `pixelBufferAdaptor`, which is attached to `videoWriterInput`.
            self.pixelBufferAdaptor
                .append(pxBuffer,
                        withPresentationTime: CMTime(value: CMTimeValue(self.frameNumber),
                                                     timescale: CMTimeScale(self.fps)))

            self.frameNumber += 1
        } else {
            return
        }
    }
}
