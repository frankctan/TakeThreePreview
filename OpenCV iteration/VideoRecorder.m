//
//  VideoRecorder.m
//  TakeThree
//
//  Created by Frank Tan on 5/4/17.
//  Copyright © 2017 franktan. All rights reserved.
//

#import "VideoRecorder.h"

@implementation VideoRecorder {

    AVAssetWriter *videoWriter;
    AVAssetWriterInput *videoWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdapter;
    CGSize resolution;
    int64_t frameNumber;
    NSURL* _url;
}

- (id)initWithResolution:(CGSize)res {
    self = [super init];

    self.fps = 30;

    self->frameNumber = 0;

    self->resolution = res;

    NSString *outputPath = [[NSString alloc] initWithFormat:@"%@%@", NSTemporaryDirectory(), @"aMov.mov"];
    NSURL *outputURL = [NSURL fileURLWithPath:outputPath];
    NSError *fileError = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:&fileError];
    }
    if(fileError) {
        NSLog(@"error: %@", fileError.description);
    }

    self->_url = outputURL;

    NSError *error = nil;
    self->videoWriter = [[AVAssetWriter alloc] initWithURL:outputURL
                                                  fileType:AVFileTypeQuickTimeMovie
                                                     error:&error];
    if(error) {
        NSLog(@"error: %@", error.description);
    }

    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:resolution.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:resolution.height], AVVideoHeightKey,
                                   nil];

    self->videoWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                                            outputSettings:videoSettings];

    self->videoWriterInput.expectsMediaDataInRealTime = YES;

    // 32-bit ARGB seems to be the default format for a cgImage.
    // Check Apple doc before changing image format in the future.
    NSDictionary *pixelBufferSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey,
                                         nil];

    self->pixelBufferAdapter = [[AVAssetWriterInputPixelBufferAdaptor alloc]
                                initWithAssetWriterInput:self->videoWriterInput
                                sourcePixelBufferAttributes:pixelBufferSettings];

    NSParameterAssert(self->videoWriterInput);
    NSParameterAssert([self->videoWriter canAddInput:self->videoWriterInput]);

    [self->videoWriter addInput:self->videoWriterInput];

    return self;
}

- (NSURL*)url {
    return self->_url;
}

- (void)start {
    bool isWriting = [self->videoWriter startWriting];
    NSParameterAssert(isWriting);
    [self->videoWriter startSessionAtSourceTime:kCMTimeZero];
}

- (void)stop {
    [self->videoWriterInput markAsFinished];

    [self->videoWriter finishWritingWithCompletionHandler:^{}];

    // Save video to camera roll.
//    [self->videoWriter finishWritingWithCompletionHandler:^{
//        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
//            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:self->videoWriter.outputURL];
//        } completionHandler:^(BOOL success, NSError *error) {
//            NSLog(@"Finished adding asset. %@", (success ? @"Success" : error));
//        }];
//    }];
}

- (void)add:(CGImageRef)image {
    // Drop frames until the system is ready for more media data.
    if (self->videoWriterInput.isReadyForMoreMediaData) {
        CVPixelBufferRef pxBuffer = NULL;

        CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL,
                                                             self->pixelBufferAdapter.pixelBufferPool,
                                                             &pxBuffer);

        NSParameterAssert(status == kCVReturnSuccess && pxBuffer != NULL);
        CVPixelBufferLockBaseAddress(pxBuffer, 0);
        void *pxdata = CVPixelBufferGetBaseAddress(pxBuffer);
        NSParameterAssert(pxdata != NULL);

        CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();

        // From OpenCV CvVideoCamera source code. These values appear to be for a cgImage.
        CGContextRef context = NULL;
        context = CGBitmapContextCreate(pxdata,
                                        self->resolution.width,
                                        self->resolution.height,
                                        8,
                                        4 * self->resolution.width,
                                        rgbColorSpace,
                                        kCGImageAlphaPremultipliedFirst);
        NSParameterAssert(context);

        CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                               CGImageGetHeight(image)), image);

        CGColorSpaceRelease(rgbColorSpace);
        CGContextRelease(context);

        // Image is released here. Otherwise app crashes in 10-20 seconds because of memory pressure.
        CGImageRelease(image);

        CVPixelBufferUnlockBaseAddress(pxBuffer, 0);

        // Increment value of frameNumber before returning.
        [self->pixelBufferAdapter appendPixelBuffer: pxBuffer
                               withPresentationTime: CMTimeMake(++self->frameNumber, self.fps)];

        // Pixel buffer is released here. Otherwise app will crash because of memory pressure.
        if (pxBuffer != NULL) {
            CVPixelBufferRelease(pxBuffer);
        }
    }
}

@end
