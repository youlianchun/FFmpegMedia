//
//  GLRenderView.h
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/11/10.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <UIKit/UIKit.h>

//NS_ASSUME_NONNULL_BEGIN
@class GLTexture;

typedef enum {
    GLTextureTypeRGB,
    GLTextureTypeYUV420P,
    GLTextureTypeYUV420SP,
} GLTextureType;

@interface GLRenderView : UIView
@property (nonatomic, readonly) CGSize textureSize;
- (id) initWithFrame:(CGRect)frame textureType:(GLTextureType)type size:(CGSize)size;
- (void) renderTexture: (GLTexture*)texture;
@end

//NS_ASSUME_NONNULL_END
