//
//  AVCodec.h
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/12/10.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "libavcodec/avcodec.h"

@class AVFrameObjBase, AVPacketObj, AVBaseStream;
NS_ASSUME_NONNULL_BEGIN

typedef enum CodecCtxType {
    CodecCtxType_unknown,
    CodecCtxType_audio,
    CodecCtxType_video,
    CodecCtxType_subtitle,
} CodecCtxType;

@interface AVCodecCtx : NSObject
@property (nonatomic, readonly) AVCodecParameters *parameters;
@property (nonatomic, readonly) AVCodecContext *context;
@property (nonatomic, readonly) const AVCodecDescriptor *descriptor;
@property (nonatomic, readonly) CodecCtxType type;
@property (nonatomic, assign) double fps;
@property (nonatomic, assign) double timeBase;
@property (nonatomic, readonly) NSString *typeStr;
+(instancetype)codecWithCodecpar:(AVCodecParameters *)codecpar;

-(void)flushBuffers;

-(BOOL)open;
-(void)close;

-(void)receiveFrame:(void(^)(AVFrameObjBase *frame))receiveCB atPacket:(AVPacketObj *)packet;
@end

NS_ASSUME_NONNULL_END
