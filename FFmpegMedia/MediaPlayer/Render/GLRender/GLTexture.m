//
//  GLTexture.m
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/11/15.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "GLTexture.h"
#import <UIKit/UIKit.h>

@implementation GLTexture
{
   @protected UIImage *_image;
}
@synthesize image = _image;
@end

@implementation GLTextureRGB
- (UIImage *) image
{
    if (!_image) {
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)(self.RGBA));
        if (provider) {
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            if (colorSpace) {
                CGImageRef imageRef = CGImageCreate(self.width,
                                                    self.height,
                                                    8,
                                                    24,
                                                    self.width,//TODO: value check?
                                                    colorSpace,
                                                    kCGBitmapByteOrderDefault,
                                                    provider,
                                                    NULL,
                                                    YES, // NO
                                                    kCGRenderingIntentDefault);
                
                if (imageRef) {
                    _image = [UIImage imageWithCGImage:imageRef];
                    CGImageRelease(imageRef);
                }
                CGColorSpaceRelease(colorSpace);
            }
            CGDataProviderRelease(provider);
        }
    }
    
    return _image;
}
@end

@implementation GLTextureYUV_P
@end

#import <CoreMedia/CoreMedia.h>
@implementation GLTextureYUV_SP
-(UIImage *)image {
    if (!_image) {
        NSDictionary *pixelAttributes = @{(id)kCVPixelBufferIOSurfacePropertiesKey : @{}};
        CVPixelBufferRef pixelBuffer = NULL;
        
        CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                              self.width,
                                              self.height,
                                              kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                              (__bridge CFDictionaryRef)(pixelAttributes),
                                              &pixelBuffer);
        CVPixelBufferLockBaseAddress(pixelBuffer,0);
        unsigned char *yDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        memcpy(yDestPlane, self.Y.bytes, self.Y.length);
        unsigned char *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        memcpy(uvDestPlane, self.UV.bytes, self.UV.length);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        if (result != kCVReturnSuccess) {
            NSLog(@"Unable to create cvpixelbuffer %d", result);
        }
        CIImage *ciImg = [CIImage imageWithCVPixelBuffer:pixelBuffer];
        CIContext *ciCtx = [CIContext contextWithOptions:nil];
        CGImageRef ciImgRef = [ciCtx
                                   createCGImage:ciImg
                                   fromRect:CGRectMake(0, 0,
                                                       self.width,
                                                       self.height)];
        
        _image = [[UIImage alloc] initWithCGImage:ciImgRef
                                            scale:UIScreen.mainScreen.scale
                                      orientation:UIImageOrientationRight];
        CVPixelBufferRelease(pixelBuffer);
        CGImageRelease(ciImgRef);
    }
    return _image;
}
@end
