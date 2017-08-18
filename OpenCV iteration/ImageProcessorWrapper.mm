//
//  ImageProcessorWrapper.m
//  TakeThree
//
//  Created by Frank Tan on 4/19/17.
//  Copyright © 2017 franktan. All rights reserved.
//

#import "ImageProcessorWrapper.h"
#import "ImageProcessor.h"
#import <opencv2/videoio/cap_ios.h>
#import <opencv2/imgcodecs/ios.h>
#import "VideoRecorder.h"

@interface ImageProcessorWrapper (PrivateMethods) <CvVideoCameraDelegate>
- (void)resizeImage:(cv::Mat&)image width:(int)width height:(int)height;
- (cv::Mat)findColorAtLocation:(CGPoint)location inFrameSize:(CGSize)size;
- (cv::Vec2d)convertPointToOpenCV:(CGPoint)point inFrameSize:(CGSize)size;
- (cv::Rect)convertRectToOpenCV:(CGRect)rect inFrameSize:(CGSize)size;
- (CGImage*)convertFromMat:(cv::Mat&)image;
@end


@implementation ImageProcessorWrapper {

    ImageProcessor* imageProcessor;

    /// What is the selected image?
    UIImage* selectedImage;

    /// This is the selectedMat of the selected image.
    cv::Mat selectedMat;

    CvVideoCamera* videoCamera;

    /// Store the videoCameraImage to be used for further processing.
    cv::Mat videoCameraImage;

    /// HSV color range
    ImageProcessor::ColorRanges colors;

    /// What part of the image is the ROI?
    cv::Rect roiRect;

    /// Which imageView is used for the videoCamera?
    UIImageView* cameraImageView;

    // TODO: - We have an isRecording here and in the view. Probably delete the one in the view.
    /// Are we recording right now?
    BOOL isRecording;

    /// Custom video recorder. Because CvVideoCamera sucks at recording things.
    VideoRecorder* videoRecorder;

    /// Is a video loaded?
    cv::VideoCapture capture;

    /// Timer associated with user-loaded video's fps.
    NSTimer *fpsTimer;

    /// Video filename.
    NSString* filePath;
}

// MARK: - Public
- (id)init {
    self = [super init];

    self->isRecording = NO;

    self->colors = { {
        ImageProcessor::Color(0, 100, 100),
        ImageProcessor::Color(10, 255, 255)
    } };
    UIImage* image = [UIImage imageNamed:@"placeholder1"];

    self->roiRect = cv::Rect(0, 0, 720, 1280);

    [self selectImage:image];
    return self;
}

- (void)appendHSVRangehL:(int)hL sL:(int)sL vL:(int)vL hH:(int)hH sH:(int)sH vH:(int)vH {
    self->colors.push_back({
        ImageProcessor::Color(hL, sL, vL),
        ImageProcessor::Color(hH, sH, vH)
    });
}

- (void)useHSVRangehL:(int)hL sL:(int)sL vL:(int)vL hH:(int)hH sH:(int)sH vH:(int)vH {
    self->colors = {{
        ImageProcessor::Color(hL, sL, vL),
        ImageProcessor::Color(hH, sH, vH)
    }};
}

- (void)clearColors {
    self->colors = ImageProcessor::ColorRanges();
}

- (void)startVideoCamera {
    [self->videoCamera start];
}

- (void)stopVideoCamera {
    [self->videoCamera stop];
}

- (void)startRecording {
    self->videoRecorder = [[VideoRecorder alloc] initWithResolution:CGSizeMake(720, 1280)];
    self->isRecording = true;
    [self->videoRecorder start];
}

- (NSURL*) stopRecording {
    [self->videoRecorder stop];
    self->isRecording = false;

    return self->videoRecorder.url;
}

- (void)selectImage:(UIImage*)image {
    // Nil out video capture and invalidate timer if user selected an image.
    self->capture.release();
    [self->fpsTimer invalidate];
    self->fpsTimer = nil;

    self->selectedImage = image;
    UIImageToMat(image, self->selectedMat, false);
    // We use absolutes here because `imageWidth` and `imageHeight` are not reliable.
    [self resizeImage:selectedMat
                width: 720
               height: 1280];
}

- (void)loadVideoMatWithTimer:(NSTimer*)timer {
    if (self->capture.isOpened()) {

        /*
         The last frame returns null mat. Use a temporary variable to determine if video ended.
        */
        cv::Mat temp = self->selectedMat;
        bool didReadFrame = self->capture.read(temp);
        if (!didReadFrame) {
            // Reload video if last frame has been read.
            // Calling `open` automatially releases the previous video.
            self->capture.open([self->filePath UTF8String]);
            self->capture.read(temp);
        }

        cv::Mat bgrTemp;
        // Convert from rgb to bgr colorspace.
        cv::cvtColor(temp, bgrTemp, CV_RGB2BGR);
        self->selectedMat = bgrTemp;

        [self resizeImage: self->selectedMat
                    width: 720
                   height: 1280];
    }
}

- (void)selectVideoWithURL:(NSString*)url fps:(float)fps {
    self->filePath = url;

    // Nil out selected image is user selected a video.
    self->selectedImage = nil;

    std::string path([url UTF8String]);
    cv::VideoCapture cap(path);

    if (!cap.isOpened()) {
        NSLog(@"could not open video");
        return;
    }

    self->capture = cap;

    self->fpsTimer = [NSTimer scheduledTimerWithTimeInterval: 1/fps
                                                      target: self
                                                    selector: @selector(loadVideoMatWithTimer:)
                                                    userInfo: nil
                                                     repeats: YES];

    [self loadVideoMatWithTimer:self->fpsTimer];
}

- (id)initVideoCameraWithImageView:(UIImageView*)imageView {
    self = [super init];
    self->cameraImageView = imageView;
    [self configureVideoCameraWithImageView:imageView];
    return self;
}

- (void)configureVideoCameraWithImageView:(UIImageView*) imageView {
    self->videoCamera = [[CvVideoCamera alloc] initWithParentView:imageView];
    self->videoCamera.delegate = self;
    self->videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self->videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset1280x720;
    self->videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self->videoCamera.defaultFPS = 30;
    self->videoCamera.grayscaleMode = NO;
}

- (void)selectedROI:(CGRect)rect inFrameSize:(CGSize)size {
    self->roiRect = [self convertRectToOpenCV:rect inFrameSize:size];
}

@end

@implementation ImageProcessorWrapper (PrivateMethods)

- (CGImage*)convertFromMat:(cv::Mat&)image {
    NSData *data = [NSData dataWithBytes:image.data length:image.elemSize()*image.total()];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaNone;

    // Creating CGImage from cv::Mat
    CGImage* dstImage = CGImageCreate(image.cols,                                 // width
                                      image.rows,                                 // height
                                      8,                                          // bits per component
                                      8 * image.elemSize(),                       // bits per pixel
                                      image.step,                                 // bytesPerRow
                                      colorSpace,                                 // colorspace
                                      bitmapInfo,                                 // bitmap info
                                      provider,                                   // CGDataProviderRef
                                      NULL,                                       // decode
                                      false,                                      // should interpolate
                                      kCGRenderingIntentDefault                   // intent
                                      );

    CGDataProviderRelease(provider);
    return dstImage;
}

- (void)resizeImage:(cv::Mat&)image width:(int)width height:(int)height {
    self->imageProcessor->resize(image, width, height);
}

- (cv::Mat)findColorAtLocation:(CGPoint)location inFrameSize:(CGSize)size {
    cv::Vec2d point = [self convertPointToOpenCV:location inFrameSize:size];
    cv::Vec4b colorBGR = self->videoCameraImage.at<cv::Vec4b>(point[0], point[1]);

    // Set to RGB color space to avoid weird errors with BGRA.
    cv::Mat result = cv::Mat::zeros(1, 1, CV_8UC3);
    result.setTo(cv::Vec3b(colorBGR[2], colorBGR[1], colorBGR[0]));

    return result;
}

- (cv::Vec2d)convertPointToOpenCV:(CGPoint)point inFrameSize:(CGSize)size {
    int xCoord = float(point.x / size.width) * 720;
    int yCoord = float(point.y / size.height) * 1280;

    return cv::Vec2d(xCoord,yCoord);
}

- (cv::Rect)convertRectToOpenCV:(CGRect)rect inFrameSize:(CGSize)size {
    // Standardize CGRect to avoid negative sizes.
    CGRect stdRect = CGRectStandardize(rect);
    cv::Vec2d cvOrigin = [self convertPointToOpenCV:stdRect.origin inFrameSize:size];

    cv::Vec2d cvSize = [self
                        convertPointToOpenCV:CGPointMake(stdRect.size.width, stdRect.size.height)
                        inFrameSize:size];

    // Ensure the ROI does not go out of bounds.
    cvOrigin[0] = cvOrigin[0] < 0 ? 0 : cvOrigin[0];
    cvOrigin[1] = cvOrigin[1] < 0 ? 0 : cvOrigin[1];
    cvSize[0] = (cvSize[0] + cvOrigin[0]) > 720 ? (720 - cvOrigin[0]) : cvSize[0];
    cvSize[1] = (cvSize[1] + cvOrigin[1]) > 1280 ? (1280 - cvOrigin[1]) : cvSize[1];


    //    NSLog(@"rect: %@ \n", NSStringFromCGRect(rect));
    //    NSLog(@"stdRect: %@ \n", NSStringFromCGRect(stdRect));
    //    std::cout << "cvRect: "
    //    << cv::Rect(cvOrigin[0], cvOrigin[1], cvSize[0], cvSize[1])
    //    << std::endl;

    //    return cv::Rect(cvOrigin[0] < 0 ? 0 : cvOrigin[0],
    //                    cvOrigin[1] < 0 ? 0 : cvOrigin[0],
    //                    cvSize[0] > self->videoCamera.imageWidth
    //                    ? self->videoCamera.imageWidth
    //                    : cvSize[0],
    //                    cvSize[1] > self->videoCamera.imageHeight
    //                    ? self->videoCamera.imageHeight
    //                    : cvSize[1]);

    return cv::Rect(cvOrigin[0], cvOrigin[1], cvSize[0], cvSize[1]);
}

#ifdef __cplusplus
- (void)processImage:(cv::Mat&)image {
    self->videoCameraImage = image;

    /// Send `ImageProcessorWrapperDelegate` a clean image to work off of.
    cv::Mat cleanRGBImage;
    cv::cvtColor(image, cleanRGBImage, CV_BGR2RGB);
    CGImageRef cgImage = [self convertFromMat:cleanRGBImage];
    [self.delegate videoCameraDidCaptureImage:cgImage];

    CGImageRelease(cgImage);

    self->imageProcessor->processImage(image,
                                       self->selectedMat,
                                       self->colors,
                                       self->roiRect);
    if (self->isRecording) {
        CGImageRef processedCGImage = [self convertFromMat:image];
        [self->videoRecorder add:processedCGImage];
    }
}

#endif

@end

