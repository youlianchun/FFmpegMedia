//
//  GLTexture.h
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/11/15.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>
@class UIImage;
@interface GLTexture : NSObject
@property (assign, nonatomic) int width;
@property (assign, nonatomic) int height;
@property (nonatomic, readonly) UIImage *image;
@end

@interface GLTextureRGB : GLTexture
@property (nonatomic, strong) NSData *RGBA;
@end

@interface GLTextureYUV_P : GLTexture
@property (nonatomic, strong) NSData *Y;
@property (nonatomic, strong) NSData *U;
@property (nonatomic, strong) NSData *V;
@end

@interface GLTextureYUV_SP : GLTexture
@property (nonatomic, strong) NSData *Y;
@property (nonatomic, strong) NSData *UV;//NV12 (iOS)
@end
