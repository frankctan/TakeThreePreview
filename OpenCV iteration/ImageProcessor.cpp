//
//  ImageProcessor.cpp
//  TakeThree
//
//  Created by Frank Tan on 4/19/17.
//  Copyright © 2017 franktan. All rights reserved.
//

#include "ImageProcessor.h"

/// Returns a grayscale (numChannels = 1) image with the specified color ranges
cv::Mat ImageProcessor::createMask(cv::Mat &image,
                                   ColorRanges ranges,
                                   cv::Rect rect) {

//    cv::Mat output = cv::Mat::zeros(image.size(), CV_8UC1);
    cv::Mat output;
    for (ColorRange range: ranges) {
        cv::inRange(image(rect),
                    range.first,
                    range.second,
                    output);
    }
    return output;
}

void ImageProcessor::processImage(cv::Mat &image,
                                  cv::Mat &selectedImage,
                                  ColorRanges colorRanges,
                                  cv::Rect rect) {
    /* 
     NOTE: - To use BGR color space, for some weird reason we need to convert from RGBA2BGR.
     Otherwise channels are swapped.
    */

    if (colorRanges.size() == 0) {
        return;
    }

    cv::Mat imageBGR, imageHSV, selectedBGR;

    // For some insane reason we have to swap R and B to get rid of the alpha channel.
    cv::cvtColor(image, imageBGR, CV_RGBA2BGR);

    // When we convert from image to HSV we don't do the channel swapping.
    cv::cvtColor(image, imageHSV, CV_BGRA2BGR);
    cv::cvtColor(imageHSV, imageHSV, CV_BGR2HSV);

    // Using `UIImageToMat` gives 4 channels. CvVideoCapture gives 3 channels.
    if (selectedImage.channels() == 4) {
        // selectedImage is BGRA. Strip out alpha channel.
        cv::cvtColor(selectedImage, selectedBGR, CV_BGRA2BGR);
    } else {
        selectedBGR = selectedImage;
    }

    // Experiment with size to see if we can reduce load on CPU.
    resize(selectedBGR, 320, 640);

    cv::Mat tempMask = createMask(imageHSV, colorRanges, cv::Rect(0,0,320,640));
    selectedBGR.copyTo(imageBGR(cv::Rect(0,0,320,640)), tempMask);
    image = imageBGR;
}

void ImageProcessor::resize(cv::Mat &image, int width, int height) {
    // Per openCV docs, CV_INTER_AREA is better for downsizing an image.
    cv::resize(image, image, cv::Size(width, height), 0, 0, CV_INTER_AREA);
}
