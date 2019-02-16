//
//  VTDecoder.h
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/11/12.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>
@class GLTexture, AVPacketObj, VideoFrame, AVCodecCtx;

NS_ASSUME_NONNULL_BEGIN

@interface VTDecoder : NSObject
-(void)setup;
-(BOOL)receiveTexture:(void(^)(GLTexture *texture))receiveCB atPacket:(AVPacketObj *)packet;

+(instancetype)decoderWithCodecCtx:(AVCodecCtx *)codecCtx;
+(BOOL)isSupport:(AVCodecCtx *)codecCtx;
@end

NS_ASSUME_NONNULL_END
@interface VTDecoder(vf)
-(BOOL)decodePacket:(AVPacketObj *)packet callback:(void(^)(VideoFrame *frame))callback;
@end
