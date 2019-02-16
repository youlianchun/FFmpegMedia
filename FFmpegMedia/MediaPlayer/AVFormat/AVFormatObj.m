//
//  AVFormatHandler.m
//  FFmpeg
//
//  Created by YLCHUN on 2018/11/7.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "AVFormatObj.h"
#import "AVObj.h"
static BOOL isNetworkPath (NSString *path)
{
    NSRange r = [path rangeOfString:@":"];
    if (r.location == NSNotFound)
        return NO;
    NSString *scheme = [path substringToIndex:r.length];
    if ([scheme isEqualToString:@"file"])
        return NO;
    return YES;
}

@implementation AVFormatObj
{
    BOOL(^_interruptCallback)(void);
    BOOL _networkDidInit;
    NSLock *_lock;
}
@synthesize path = _path;
@synthesize isNetworkPath = _isNetworkPath;
@synthesize context = _context;
@synthesize didOpen = _didOpen;

-(instancetype)initWithPath:(NSString *)path interruptCallback:(BOOL(^)(void))callback {
    if (self = [super init]) {
        _path = path;
        _isNetworkPath = isNetworkPath(_path);
        _interruptCallback = callback;
        _lock = [NSLock new];
    }
    return self;
}

-(BOOL)hadInterrupt {
    if (_interruptCallback)
        return _interruptCallback();
    return NO;
}

static int interrupt_callback(void *ctx)
{
    if (!ctx)
        return 0;
    __unsafe_unretained AVFormatObj *p = (__bridge AVFormatObj *)ctx;
    return [p hadInterrupt];
}

-(BOOL)open {
    if (_isNetworkPath) {
         avformat_network_init();
        _networkDidInit = YES;
    }
    
    AVFormatContext *formatCtx = NULL;
    
    if (_interruptCallback) {
        formatCtx = avformat_alloc_context();
        if (!formatCtx)
            return NO;
        formatCtx->interrupt_callback.callback = interrupt_callback;
        formatCtx->interrupt_callback.opaque = (__bridge void *)(self);
    }
    
    // 打开文件流
    if (avformat_open_input(&formatCtx, [_path cStringUsingEncoding: NSUTF8StringEncoding], NULL, NULL) < 0) {
        if (formatCtx)
            avformat_free_context(formatCtx);
        return NO;
    }
    
    // 获取流信息
    if (avformat_find_stream_info(formatCtx, NULL) < 0) {
        avformat_close_input(&formatCtx);
        return NO;
    }
    
    // 打印有关数据
    av_dump_format(formatCtx, 0, [_path.lastPathComponent cStringUsingEncoding: NSUTF8StringEncoding], false);
    
//    av_log_set_level(AV_LOG_QUIET);
    
    _context = formatCtx;
    _didOpen = YES;
    
    return YES;
}

-(double)duration {
    if (!_context)
        return 0;
    if (_context->duration == AV_NOPTS_VALUE)
        return MAXFLOAT;
    return _context->duration / AV_TIME_BASE;
}

-(void)close {
    if (_networkDidInit) {
        avformat_network_deinit();
    }
    
    if (_context) {
        avformat_close_input(&_context);
        
        _context->interrupt_callback.opaque = NULL;
        _context->interrupt_callback.callback = NULL;
        
        avformat_free_context(_context);
        _context = NULL;
    }
    _didOpen = NO;
}

-(void)play {
    av_read_play(_context);
}

-(void)pause {
    av_read_pause(_context);
}


-(void)seek:(int)streamIdx time:(int64_t)ts {
    [_lock lock];
    avformat_seek_file(_context, streamIdx, ts, ts, ts, AVSEEK_FLAG_FRAME);
    [_lock unlock];
}

-(AVPacketObj *)readPacket {
    AVPacketObj *obj = [AVPacketObj bridge2ObjWith:av_packet_alloc()];
    [_lock lock];
    BOOL success = av_read_frame(_context, obj.data) == 0;
    [_lock unlock];
    if (!success) {
        return nil;
    }
    enum AVMediaType type = self.context->streams[obj.data->stream_index]->codecpar->codec_type;
    obj.type = toPacketType(type);
    return obj;
}

static AVPacketType toPacketType(enum AVMediaType type) {
    switch (type) {
        case AVMEDIA_TYPE_AUDIO:
            return AVPacketType_audio;
        case AVMEDIA_TYPE_VIDEO:
            return AVPacketType_video;
        case AVMEDIA_TYPE_SUBTITLE:
            return AVPacketType_suntitle;
        default:
            return AVPacketType_unknown;
    }
}

@end
