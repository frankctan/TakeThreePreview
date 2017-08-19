//
//  VideoRecorder.h
//  TakeThree
//
//  Created by Frank Tan on 5/4/17.
//  Copyright © 2017 franktan. All rights reserved.
//

#ifndef VideoRecorder_h
#define VideoRecorder_h


#endif /* VideoRecorder_h */


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>


@interface VideoRecorder : NSObject

- (id)initWithResolution:(CGSize)res;
- (void)start;
- (void)stop;
- (void)add:(CGImageRef)image;

@property (nonatomic, assign) int32_t fps;
@property (nonatomic, readonly) NSURL* url;

@end
