import UIKit
import CoreImage
import Foundation
import GLKit
import PlaygroundSupport

/**
 Proof-of-concept code snippet to test image composition with 
 transparent backgrounds. Rotated images' frames are (usually)
 enlarged relative to the frame of the original image. The 
 "empty space" results in transparent pixels.
 */
PlaygroundPage.current.needsIndefiniteExecution = true

// Initialize Images.
let batmanURL = URL(fileReferenceLiteralResourceName: "batman.png")
let batman: CIImage! = CIImage(contentsOf: batmanURL)

let supermanURL = URL(fileReferenceLiteralResourceName: "superman.png")
let superman: CIImage! = CIImage(contentsOf: supermanURL)

// Initialize contexts wiht openGL, which causes rendering on the GPU.
let glContext: EAGLContext! = EAGLContext(api: .openGLES2)
let ciContext: CIContext = CIContext(eaglContext: glContext)


// Perform an arbitrary transformation.
let transform = CGAffineTransform(translationX: 200, y: 0)
let duplicateImage: CIImage! = superman.applying(transform)

// Overlay supermen on top of each other.
let _image: CIImage! = superman.compositingOverImage(duplicateImage)

// Rotate supermen.
let rotTrans = CGPoint(x: _image.extent.width / 2,
                       y: _image.extent.height / 2)
let rotation =
    CGAffineTransform(translationX: rotTrans.x,
                      y: rotTrans.y)
        .rotated(by: .pi / 4)
        .translatedBy(x: -rotTrans.x, y: -rotTrans.y)

/* 
Superimpose rotated supermen on top of batman logo.
 
Supermen background are transparent so the batman logo is obstructed.
*/
let image = _image.applying(rotation).compositingOverImage(batman)

/**
 Fill the drawable area while preserving aspect ratio.
 
 - parameter imageSize: what is the size of the image?
 - parameter drawableSize: what is the size of the drawable area?
 - returns: scaled rectangle with origin of `.zero`.
 */
func calculateDrawableRect(imageSize: CGSize,
                           drawableSize: CGSize) -> CGRect {
    let xScale = imageSize.width / drawableSize.width
    let yScale = imageSize.height / drawableSize.height

    let scale = max(xScale, yScale)

    let appliedScaleFactor = 1 / scale

    let imageWidth = imageSize.width * appliedScaleFactor
    let imageHeight = imageSize.height * appliedScaleFactor

    let originX: CGFloat = 0.0
    let originY: CGFloat = 0.0

    return CGRect(x: originX, y: originY, width: imageWidth, height: imageHeight)
}

let glView =
    GLKView(frame: CGRect(x: 0, y: 0, width: 600, height: 500),
            context: glContext)

// Must set current eagl context to the retained eaglContext.
if glContext != EAGLContext.current() {
    EAGLContext.setCurrent(glContext)
}

let drawableSize = CGSize(width: glView.drawableWidth,
                          height: glView.drawableHeight)
let scaledRect =
    calculateDrawableRect(imageSize: image.extent.size,
                          drawableSize: drawableSize)

// Draw image into the glView.
glView.bindDrawable()
ciContext.draw(image,
               in: scaledRect,
               from: image.extent)
glView.display()
PlaygroundPage.current.liveView = glView
