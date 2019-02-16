//
//  PacketDecoder.h
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/12/15.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVConvert.h"
#import "DecoderType.h"

@class AVCodecCtx, AVPacketObj, AVBaseFrame;
NS_ASSUME_NONNULL_BEGIN

@interface PacketDecoder : NSObject
@property (nonatomic, readonly) AVCodecCtx *codecCtx;
@property (nonatomic, readonly) NSUInteger frameCount;
-(instancetype)initWithCodecCtx:(AVCodecCtx *)codecCtx convertCls:(Class<AVConvert>)convertCls frameCls:(Class)frameCls;
-(void)stop;
-(void)start;
-(void)clean;
-(void)setIsPreview:(BOOL)isPreview;
-(void)sendPacket:(AVPacketObj *)packet;
-(AVBaseFrame *)getFrame;
@end

@interface VideoPacketDecoder : PacketDecoder
@property (nonatomic, readonly) double width;
@property (nonatomic, readonly) double height;
@property (nonatomic, readonly) VideoTextureType type;
@end
NS_ASSUME_NONNULL_END

