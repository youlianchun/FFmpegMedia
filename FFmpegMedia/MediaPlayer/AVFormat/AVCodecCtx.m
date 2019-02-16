//
//  AVCodec.m
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/12/10.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "AVCodecCtx.h"
#import "AVObj.h"

@implementation AVCodecCtx
{
    AVCodec *_codec;
    NSLock *_lock;
}
@synthesize parameters = _parameters;
@synthesize context = _context;
@synthesize type = _type;

+(instancetype)codecWithCodecpar:(AVCodecParameters *)codecpar {
    if (!codecpar) return nil;
    return [[self alloc] initWithCodecpar:codecpar];
}

-(instancetype)initWithCodecpar:(AVCodecParameters *)codecpar {
    self = [super init];
    if (self) {
        _codec = avcodec_find_decoder(codecpar->codec_id);
        _context = get_codec_context(codecpar);
        _parameters = codecpar;
        _type = get_codec_type(codecpar);
        _lock = [NSLock new];
    }
    return self;
}

-(NSString *)typeStr {
    switch (_type) {
        case CodecCtxType_audio:
            return @"CodecCtxType_audio";
            break;
        case CodecCtxType_video:
            return @"CodecCtxType_video";
        case CodecCtxType_subtitle:
            return @"CodecCtxType_subtitle";
        default:
            return @"CodecCtxType_unknown";
            break;
    }
}

-(BOOL)open {
    return avcodec_open2(_context, _codec, NULL) == 0;
}

-(void)close {
    avcodec_close(_context);
}

-(void)dealloc {
    avcodec_free_context(&_context);
}

-(const AVCodecDescriptor *)descriptor {
    if (!_context) return NULL;
    return avcodec_descriptor_get(_context->codec_id);
}

-(void)flushBuffers {
    [_lock lock];
    avcodec_flush_buffers(_context);
    [_lock unlock];
}

-(BOOL)sendPacket:(AVPacketObj *)packet {
    [_lock lock];
    int n = avcodec_send_packet(_context, packet.data);
    [_lock unlock];
    return n == 0;
}

-(AVFrameObj *)receiveFrame {
    AVFrameObj *frame = [AVFrameObj bridge2ObjWith:av_frame_alloc()];
    if (!frame.data) {
        return nil;
    }
    
    [_lock lock];
    int n = avcodec_receive_frame(_context, frame.data);
    [_lock unlock];
    
    if (n != 0) {
        return nil;
    }
    return frame;
}


-(void)receiveAVFrame:(void(^)(AVFrameObj *frame))receiveCB atPacket:(AVPacketObj *)packet {
    if (![self sendPacket:packet]) {
        return;
    }
    while (true) {
        AVFrameObj *frame = [self receiveFrame];
        if (!frame) {
            break;
        }
        receiveCB(frame);
    }
}

-(void)receiveSubtitle:(void(^)(AVSubtitleObj *frame))receiveCB atPacket:(AVPacketObj *)packet {
    int pktSize = packet.data->size;
    while (pktSize > 0) {
        AVSubtitleObj *subtitle = [AVSubtitleObj bridge2ObjWith:av_malloc(sizeof(AVSubtitle))];
        int gotsubtitle = 0;
        [_lock lock];
        int len = avcodec_decode_subtitle2(_context, subtitle.data, &gotsubtitle, packet.data);
        [_lock unlock];
        if (len < 0) break;
        if (gotsubtitle) {
            receiveCB(subtitle);
        }
        if (0 == len)
            break;
        pktSize -= len;
    }
}



-(void)receiveFrame:(void(^)(AVFrameObjBase *frame))receiveCB atPacket:(AVPacketObj *)packet {
    if (!receiveCB) return;
    switch (self.type) {
        case CodecCtxType_audio:
        case CodecCtxType_video:
            [self receiveAVFrame:receiveCB atPacket:packet];
            break;
        case CodecCtxType_subtitle:
            [self receiveSubtitle:receiveCB atPacket:packet];
            break;
        default:
            
            break;
    }
}

static CodecCtxType get_codec_type(AVCodecParameters *parameters) {
    switch (parameters->codec_type) {
        case AVMEDIA_TYPE_AUDIO:
            return CodecCtxType_audio;
            break;
        case AVMEDIA_TYPE_VIDEO:
            return CodecCtxType_video;
            break;
        case AVMEDIA_TYPE_SUBTITLE:
            return CodecCtxType_subtitle;
            break;
        default:
            return CodecCtxType_unknown;
            break;
    }
}


static AVCodecContext *get_codec_context(AVCodecParameters *codecpar)
{
    if (!codecpar) return NULL;
    
    AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
    int ret = avcodec_parameters_to_context(codecCtx, codecpar);
    
    if (ret < 0) {
        //Copy stream failed!
        avcodec_free_context(&codecCtx);
        codecCtx = NULL;
    }
    return codecCtx;
}

@end
