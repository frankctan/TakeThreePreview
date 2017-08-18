//
//  ImageProcessor.h
//  TakeThree
//
//  Created by Frank Tan on 4/19/17.
//  Copyright © 2017 franktan. All rights reserved.
//

#ifndef ImageProcessor_h
#define ImageProcessor_h


#endif

#include <vector>


class ImageProcessor {
public:
    /// Type of color representation should be specified upon declaration.
    using Color = cv::Vec3b;
    using ColorRange = std::pair<Color, Color>;
    using ColorRanges = std::vector<ColorRange>;

    cv::Mat createMask(cv::Mat &image,
                       ColorRanges ranges,
                       cv::Rect rect);

    void processImage(cv::Mat &image,
                      cv::Mat &selectedImage,
                      ColorRanges colorRanges,
                      cv::Rect rect);

    void resize(cv::Mat &image, int width, int height);
};
