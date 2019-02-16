//
//  AVFrames.h
//  FFmpeg
//
//  Created by YLCHUN on 2018/11/5.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BufferQueueElement.h"
#import "AVConvert.h"

@class GLTexture;
@interface AVBaseFrame : NSObject<BufferQueueElement>
@property (nonatomic, readonly) double position;
@property (nonatomic, readonly) double duration;
@property (nonatomic, readonly) id data;
+(instancetype)frameWithConvert:(id<AVConvert>)convert avframe:(AVFrameObjBase *)avframe;
@end

@interface AudioFrame : AVBaseFrame
@property (nonatomic, readonly) NSData *data;
@end

@interface VideoFrame : AVBaseFrame
@property (nonatomic, readonly) GLTexture *data;
+(instancetype)frameWithTexture:(GLTexture *)texture pos:(double)pos dur:(double)dur ;

@end

@interface SubtitleFrame : AVBaseFrame
@property (nonatomic, readonly) NSString *data;
@end

@class UIImage;
@interface ArtworkFrame : AVBaseFrame
@property (nonatomic, readonly) NSData *data;
- (UIImage *) image;
@end
