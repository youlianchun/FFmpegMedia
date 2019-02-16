//
//  AVFrames.m
//  FFmpeg
//
//  Created by YLCHUN on 2018/11/5.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "AVFrames.h"
#import <UIKit/UIKit.h>
#import "AVObj.h"

@interface AVBaseFrame()
@property (nonatomic, assign) double position;
@property (nonatomic, assign) double duration;
@property (nonatomic, strong) id data;
@end

@implementation AVBaseFrame
@synthesize sign;

+(instancetype)frameWithConvert:(id<AVConvert>)convert avframe:(AVFrameObjBase *)avframe {
    __block AVBaseFrame *frame;
    [convert receive:^(id data, double duration, double position) {
        frame = [[self alloc] init];
        frame.position = position;
        frame.duration = duration;
        frame.data = data;
    } atAVObj:avframe];
    return frame;
}
@end


@implementation AudioFrame
@dynamic data;
@end


@implementation VideoFrame
@dynamic data;
+(instancetype)frameWithTexture:(GLTexture *)texture pos:(double)pos dur:(double)dur {
    VideoFrame *frame = [super new];
    frame.data = texture;
    frame.position = pos;
    frame.duration = dur;
    return frame;
}
@end


@implementation SubtitleFrame
@dynamic data;
@end

@implementation ArtworkFrame
@dynamic data;

- (UIImage *) image {
    UIImage *image = nil;
    CGDataProviderRef dataProviderRef = CGDataProviderCreateWithCFData((__bridge CFDataRef)(self.data));
    if (dataProviderRef) {
        CGImageRef imageRef = CGImageCreateWithJPEGDataProvider(dataProviderRef, NULL, YES, kCGRenderingIntentDefault);
        CGDataProviderRelease(dataProviderRef);
        if (imageRef) {
            image = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
        }
    }
    return image;
}
@end
