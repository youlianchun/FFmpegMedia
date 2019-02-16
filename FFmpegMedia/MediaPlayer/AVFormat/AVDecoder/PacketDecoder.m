//
//  PacketDecoder.m
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/12/15.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "PacketDecoder.h"
#import "SubtitleConvert.h"
#import "VTDecoder.h"
#import "BufferQueue.h"
#import "AVFrames.h"
#import "AVObj.h"
#import "AVCodecCtx.h"

@interface PacketDecoder ()<BufferQueueDelegate>
@end

@implementation PacketDecoder
{
    BufferQueue *_queue;
    id<AVConvert> _convert;
    AVCodecCtx *_codecCtx;
    Class _frameCls;
}
@synthesize codecCtx = _codecCtx;

-(instancetype)initWithCodecCtx:(AVCodecCtx *)codecCtx convertCls:(Class<AVConvert>)convertCls frameCls:(Class)frameCls {
    self = [super init];
    if (self) {
        _convert = [convertCls convertWithCodecCtx:codecCtx];
        _codecCtx = codecCtx;
        _queue = [[BufferQueue alloc] initWithDelegate:self];
        _frameCls = frameCls;
    }
    return self;
}

-(void)bufferQueue:(BufferQueue *)queue receiveOutElement:(void (^)(BQElement _Nonnull))receiveElement atInElement:(BQElement)inElement {
//    NSLog(@"0 ..decoder %d", self->_codecCtx.type);
    [_codecCtx receiveFrame:^(AVFrameObjBase * _Nonnull frame) {
        AVBaseFrame *obj = [self->_frameCls frameWithConvert:self->_convert avframe:frame];
        NSAssert(obj, @"decode failed");
//        NSLog(@"1 ..decoder %d", self->_codecCtx.type);
        receiveElement(obj);
    } atPacket:inElement];
}

-(void)stop {
    [_queue stop];
}

-(void)start {
    [_queue start];
}

-(void)clean {
    [_queue clean];
}

-(void)setIsPreview:(BOOL)isPreview {
    int size = isPreview ? 1 : 40;
    [_queue setSendThreshold:size];
}

-(void)sendPacket:(AVPacketObj *)packet {
    [_queue sendInElement:packet];
}

-(AVBaseFrame *)getFrame {
    NSLog(@"type: %@, count: %ld", _codecCtx.typeStr, _queue.count);
    return [_queue getOutElement];
}

-(NSUInteger)frameCount {
    return _queue.count;
}

@end


@implementation VideoPacketDecoder
{
    VTDecoder *_vtDecoder;
}

-(instancetype)initWithCodecCtx:(AVCodecCtx *)codecCtx convertCls:(Class<AVConvert>)convertCls frameCls:(Class)frameCls {
    self = [super initWithCodecCtx:codecCtx convertCls:convertCls frameCls:frameCls];
    if (self) {
#if !TARGET_IPHONE_SIMULATOR
        if (!kDisableVTDecode) {
            _vtDecoder = [VTDecoder decoderWithCodecCtx:codecCtx];
        }
#endif
    }
    return self;
}

-(void)bufferQueue:(BufferQueue *)queue receiveOutElement:(void (^)(BQElement _Nonnull))receiveElement atInElement:(BQElement)inElement {
    if (_vtDecoder) {
        [_vtDecoder decodePacket:inElement callback:^(VideoFrame *frame) {
            NSAssert(frame, @"decode failed");
            receiveElement(frame);
        }];
    }else  {
        [super bufferQueue:queue receiveOutElement:receiveElement atInElement:inElement];
    }
}

-(void)start {
    [_vtDecoder setup];
    [super start];
}

-(double)width {
    return self.codecCtx.context->width;
}

-(double)height {
    return self.codecCtx.context->height;
}

-(VideoTextureType)type {
    if (_vtDecoder) {
        return VideoTextureType_yuv420sp;
    }else if (self.codecCtx.context->pix_fmt == AV_PIX_FMT_YUV420P || self.codecCtx.context->pix_fmt == AV_PIX_FMT_YUVJ420P) {
        return VideoTextureType_yuv420p;
    }else {
        return VideoTextureType_rgb;
    }
}

@end
