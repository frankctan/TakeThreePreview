//
//  ImageProcessorWrapper.h
//  TakeThree
//
//  Created by Frank Tan on 4/19/17.
//  Copyright © 2017 franktan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

@protocol ImageProcessorWrapperDelegate
- (void)videoCameraDidCaptureImage:(CGImageRef)image;
@end

@interface ImageProcessorWrapper : NSObject

@property (nonatomic, weak) id<ImageProcessorWrapperDelegate> delegate;

- (void)selectImage:(UIImage*)image;

- (void)selectVideoWithURL:(NSString*)url fps:(float)fps;

- (id)initVideoCameraWithImageView:(UIImageView*) imageView;

- (void)configureVideoCameraWithImageView:(UIImageView*) imageView;

- (void)startVideoCamera;

- (void)startRecording;

- (NSURL*)stopRecording;

- (void)stopVideoCamera;

- (id)init;

- (void)selectedROI:(CGRect)rect inFrameSize:(CGSize)size;

- (void)appendHSVRangehL:(int)hL sL:(int)sL vL:(int)vL hH:(int)hH sH:(int)sH vH:(int)vH;

- (void)useHSVRangehL:(int)hL sL:(int)sL vL:(int)vL hH:(int)hH sH:(int)sH vH:(int)vH;

- (void)clearColors;

@end
