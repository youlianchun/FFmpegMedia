//
//  AVStreams.m
//  FFmpeg
//
//  Created by YLCHUN on 2018/11/7.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "AVStreams.h"

static void get_fps_timeBase(AVStream *stream, double timeBaseDef, double *fpsPtr, double *timeBasePtr)
{
    double fps, timebase;
    
    // ffmpeg提供了一个把AVRatioal结构转换成double的函数
    // 默认0.04 意思就是25帧
    if (stream->time_base.den && stream->time_base.num)
        timebase = av_q2d(stream->time_base);
    else if(stream->time_base.den && stream->time_base.num)
        timebase = av_q2d(stream->time_base);
    else
        timebase = timeBaseDef;
    
    //    if (st->codec->ticks_per_frame != 1) {
//            NSLog(@"WARNING: st.codec.ticks_per_frame=%d", st->codec->ticks_per_frame);
    //        //timebase *= st->codec->ticks_per_frame;
    //    }
    
    // 平均帧率
    if (stream->avg_frame_rate.den && stream->avg_frame_rate.num)
        fps = av_q2d(stream->avg_frame_rate);
    else if (stream->r_frame_rate.den && stream->r_frame_rate.num)
        fps = av_q2d(stream->r_frame_rate);
    else
        fps = 1.0 / timebase;
    
    if (fpsPtr)
        *fpsPtr = fps;
    if (timeBasePtr)
        *timeBasePtr = timebase;
}


@implementation AVBaseStream
{
    AVFormatObj *_format;
    NSArray<NSNumber *> *_streamInxArr;
}
@synthesize codecCtx = _codecCtx;
@synthesize timeBase = _timeBase;
@synthesize fps = _fps;
@synthesize streamIdx = _streamIdx;

-(AVStream *)stream {
    if (_streamIdx == -1 || !_format.didOpen) return NULL;
    return _format.context->streams[_streamIdx];
}

-(instancetype)initWithFormat:(AVFormatObj *)format {
    self = [super init];
    if (self) {
        _streamIdx = -1;
        _format = format;
    }
    return self;
}

static int check_stream_specifier(AVFormatContext *s, AVStream *st, const char *spec)
{
    int ret = avformat_match_stream_specifier(s, st, spec);
    if (ret < 0)
        av_log(s, AV_LOG_ERROR, "Invalid stream specifier: %s.\n", spec);
    return ret;
}

-(BOOL)openCodecWithStreamIdx:(NSUInteger )streamIdx defTimeBase:(double)defTimeBase suppordCheck:(BOOL(^)(const AVCodecDescriptor *codecDesc))suppordCheck {
    if (!_format.didOpen) return NO;
    
    AVStream *stream = _format.context->streams[streamIdx];
    AVCodecCtx *codecCtx = [AVCodecCtx codecWithCodecpar:stream->codecpar];
    BOOL isSup = suppordCheck?suppordCheck(codecCtx.descriptor):YES;
    if (isSup && ![codecCtx open]) {
        return NO;
    }
    if (defTimeBase > 0) {
        get_fps_timeBase(stream, defTimeBase, &_fps, &_timeBase);
    }
    codecCtx.fps = _fps;
    codecCtx.timeBase = _timeBase;
    _codecCtx = codecCtx;

    _streamIdx = streamIdx;
    return YES;
}

-(void)filtrateStreamWithType:(enum AVMediaType)codecType didFind:(BOOL(^)(NSInteger streamIdx))didFind {
    if (!_format.didOpen) return;
    
    for (NSInteger idx = 0; idx < _format.context->nb_streams; ++idx) {
        if (codecType != _format.context->streams[idx]->codecpar->codec_type) continue;
        if (didFind(idx)) break;
    }
}

-(void)setPosition: (double)seconds {
    if (_streamIdx != -1) {
        int64_t ts = (int64_t)(seconds / _timeBase);
        [_format seek:_streamIdx time:ts];
        [_codecCtx flushBuffers];
    }
}

-(BOOL)checkStreamIdx:(NSInteger)index {
    if (index < 0 || (_format.didOpen && index >= _format.context->nb_streams))
        return NO;
    if (_streamInxArr) {
        for (NSNumber *s in _streamInxArr) {
            if (s.integerValue == index)
                return YES;
        }
        return NO;
    }else {
        return YES;
    }
}

-(BOOL)changeStreamIdx:(NSInteger)index {
    if (![self checkStreamIdx:index]) return NO;
    return NO;
}

-(BOOL)openCodec {
    if (_format.didOpen) {
        return YES;
    }
    return NO;
}

-(void)closeCodec {
    _streamIdx = -1;
}
-(BOOL)didOpen {
    return _streamIdx != -1;
}

@end


/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

@implementation AudioStream

-(BOOL)openCodec {
    if (![super openCodec]) {
        return NO;
    }
    __block BOOL success = NO;
    [super filtrateStreamWithType:AVMEDIA_TYPE_AUDIO didFind:^BOOL(NSInteger streamIdx) {
        success = [self changeStreamIdx:streamIdx];
        return success;
    }];
    return success;
}

-(BOOL)changeStreamIdx:(NSInteger)index  {
    if (![super checkStreamIdx:index]) return NO;
    if (index == self.streamIdx) return YES;
    
   return [super openCodecWithStreamIdx:index defTimeBase:0.025 suppordCheck:NULL];
}

@end

/////////////////////////////////////////////////////////////////////////////////////

@implementation VideoStream
-(BOOL)openCodec {
    if (![super openCodec]) {
        return NO;
    }
    __block BOOL success = NO;
    [super filtrateStreamWithType:AVMEDIA_TYPE_VIDEO didFind:^BOOL(NSInteger streamIdx) {
        success = [self changeStreamIdx:streamIdx];
        return success;
    }];
    return success;
}

-(BOOL)changeStreamIdx:(NSInteger)index  {
    if (![super checkStreamIdx:index]) return NO;
    if (index == self.streamIdx) return YES;
    
    return [super openCodecWithStreamIdx:index defTimeBase:0.04 suppordCheck:NULL];
}

@end

/////////////////////////////////////////////////////////////////////////////////////

@implementation SubtitleStream
@dynamic timeBase;
@dynamic fps;

-(BOOL)openCodec {
    if (![super openCodec]) {
        return NO;
    }
    __block BOOL success = NO;
    [super filtrateStreamWithType:AVMEDIA_TYPE_SUBTITLE didFind:^BOOL(NSInteger streamIdx) {
        success = [self changeStreamIdx:streamIdx];
        return success;
    }];
    return success;
}

-(BOOL)changeStreamIdx:(NSInteger)index {
    if (![super checkStreamIdx:index]) return NO;
    if (index == self.streamIdx) return YES;
    
    return [super openCodecWithStreamIdx:index defTimeBase:0 suppordCheck:^BOOL(const AVCodecDescriptor *codecDesc) {
        return !(codecDesc->props & AV_CODEC_PROP_BITMAP_SUB);
    }];
}

@end
