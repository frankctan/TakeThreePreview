# TakeThree

TakeThree is an iOS app which enables a user to apply a green screen effect in real time. Here are some previews:

First, we select and fine-tune a color for the green screen and then we resize our media:

![color](http://i.imgur.com/00jTu08.gif) ![media](http://i.imgur.com/GpJ9G0d.gif)

Next, we create a snazzy video by overlaying two green screen effects on top of each other!
![zoomheart](http://i.imgur.com/06XuxOF.gif) ![final](http://i.imgur.com/tMSwEph.gif)

## Thoughts on Development
I started by using OpenCV's iOS framework (code in folder above). This didn't work very well -
- OpenCV performs all calculations on the device CPU
- OpenCV's iOS wrapper is error-prone and poorly documented

As I hovered around the finish line of TakeThree v1, I was regularly exceeding 90% of CPU usage on my iPhone 7 according to xcode's debugging tools. Further, I found myself re-writing large portions of the iOS wrapper because of buggy or unsupported functionality. This was unacceptable.

The final version of TakeThree is written using Apple's CoreImage framework. So many good things to say. Here are a few:
- CPU usage rarely exceeded 40%
- Extensive documentation and examples provided
- Quick iteration using Playgrounds
- Maintained by Apple - easily compatible with all other Apple frameworks. No need to rely on third party code for the most performance-sensitive components

Using CoreImage, I was able to offload a significant chunk of work onto the GPU. A simple example is video recording. OpenCV returns a `CGImage`, which is passed to the `VideoRecorder` object. A `CGImage` is a bitmap stored in memory, which is drawn into a pixel buffer using a `CGContext`, which uses the CPU.

By contrast, a `CIImage` is simply a representation of an image which contains information about what the final image should look like. The final output is processed lazily - only on request. A `CIImage` can be directly rendered using the GPU into a `VideoRecorder` pixel buffer using a `CIContext`. Using CoreImage prevents unncessary and expensive jumps between the CPU and GPU.

Another alternative to OpenCV and CoreImage is GPUImage. GPUImage is a third party library which claims roughly the same image processing performance as CoreImage. A clear entry in GPUImage's "pro" column is the ability to directly use OpenGL files in an xcode project. While CoreImage technically supports OpenGL code, the code must be inserted as a string. Complicated image processing code injected into CoreImage as a string seems like a really bad idea. However, after some research, I found that CoreImage's 100's of built-in filters more than suited my needs when chained together.

Below is a brief bullet point summary of the technical details of the gifs above. Questions and comments are welcome!

## Camera Configuration
- Image rendered on the GPU using a `GLKView`
- Video output is processed using a sample buffer, which is  `[Color]`, which is `[Uint8]` of size 4 (color channels) * 720 (width) * 1280 (height)

## Color State (1st image)
- Gesture recognizer returns tapped coordinate
- Tapped coordinate is converted from `UIKit` coordinate system to `CoreImage` coordinate system
- User-tapped color is retrieved from the sample buffer using the `CoreImage` coordinate
- Shadows, color inconsistencies in the livew preview, etc. cause enough variation such that user intention usually can't be conveyed using only one RGB color. We need a range of colors
- Range of colors (user intent) can be derived in a number of ways. Ultimately settled on a flat hue-saturation-value color thresholding
- User can fine-tune the "value" component of the color range using a two-handle slider

## Media State (2nd image)
- User can choose to use the default video clip or pick their own still image or video
- Selected media can be modified using pinch / pan / rotate gestures

## Default State (4th image)
- User has the option to fine tune color, choose new media or reset entirely
- User can pick between taking a still photo or a video
- Video / still photo preview is displayed in a modal, giving user the option to save or re-take

# Navigation
- `Coordinator`s are used to separate app state and navigation responsibilities from view controllers
- VC's delegate up to the coordinator, which present or dismiss VCs and calls image processor as needed
- Modal permission prompts are shown for first-time users

## Notifications (1st, 3rd, 4th images, sample code provided)
- Used to guide users through the app's interface
- Notifications UX should be the same across the entire app, so notifications are written as a protocol with many default methods instead of a viewcontroller subclass to preserve future extensibility

# Loading Video
- `CADisplayLink` timer synchronizes display refresh rate
- `AVPlayer` points to the target video, `AVPlayerItemVideoOutput` retrieves the selected frame at a given time

# Recording Video
- `AVAssetWriter` writes media data to a container type
- `AVAssetWriterInput` writes to a track of the `AVAssetWriter`
- `AVAssetWriterInputPixelAdaptor` manages a pool of pixel buffers which are added to the input
