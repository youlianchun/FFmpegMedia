//
//  SwrConvert.m
//  FFmpeg
//
//  Created by YLCHUN on 2018/11/5.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "AudioConvert.h"
#import <Accelerate/Accelerate.h>
#import "libswresample/swresample.h"
#import "libavformat/avformat.h"
#import "AudioRender.h"
#import "AVStreams.h"
#import "AVObj.h"

@implementation AudioConvert
{
    AVCodecCtx *_codecCtx;
    SwrContext  *_swrContext;
    
    int _numChannels;
    int _samplingRate;
    
    BOOL _needConvert;
}

+(instancetype)convertWithCodecCtx:(AVCodecCtx *)codecCtx {
    return [[AudioConvert alloc] initWithCodecCtx:codecCtx];
}

-(instancetype) initWithCodecCtx:(AVCodecCtx *)codecCtx  {
    if (self = [super init]) {
        AudioRender *rander = [AudioRender sharedInstance];
        _codecCtx = codecCtx;
        _samplingRate = rander.samplingRate;
        _numChannels = rander.channels;
        _needConvert = !isFMT_S16(codecCtx.context, _numChannels, _samplingRate);
    }
    return self;
}

-(void)dealloc {
    if (_swrContext) {
        swr_free(&_swrContext);
        _swrContext = NULL;
    }
    _codecCtx = nil;
}

-(enum AVSampleFormat)fmt {
    return AV_SAMPLE_FMT_S16;
}

-(SwrContext *)swrContext {
    if (!_swrContext) {
        _swrContext = swr_alloc_set_opts(NULL,
                                         av_get_default_channel_layout(_numChannels),
                                         self.fmt,
                                         _samplingRate,
                                         av_get_default_channel_layout(_codecCtx.context->channels),
                                         _codecCtx.context->sample_fmt,
                                         _codecCtx.context->sample_rate,
                                         0,
                                         NULL);
    }
    return _swrContext;
}

-(void)receive:(void(^)(NSData *data, double duration, double position))receiveCB atAVObj:(AVFrameObjBase *)avObj {
    if (!receiveCB || !avObj || ![avObj isKindOfClass:[AVFrameObj class]]) return;
    
    AVFrameObj *frame = (AVFrameObj *)avObj;
    if (!frame.data->data[0]) return;
    AVFrameObj *obj;
    if (_needConvert) {
        AVFrame *nframe = convertFormat(frame.data, self.fmt, _samplingRate, _numChannels, self.swrContext);//注意frame转换后的数据正确性
        if (!nframe) {
            NSLog(@"转换失败");
        }
        obj = [AVFrameObj bridge2ObjWith:nframe];
    }
    if (!obj) obj = frame;
    
    NSData *data = get_audioData_vDSP(obj.data);

    double position = obj.data->best_effort_timestamp * _codecCtx.timeBase;
    double duration = obj.data->pkt_duration * _codecCtx.timeBase;
    
    if (duration == 0) {
        // 无法获取到时间时需进行计算，如 wma/wmv 等，channels 和 nb_samples 参数j校验
        duration = data.length / (sizeof(float) * obj.data->channels * obj.data->nb_samples);
    }
    
    receiveCB(data, duration, position);
}

static NSData *get_audioData_vDSP(AVFrame *frame) {
    void *audioData = frame->data[0];
    const NSUInteger numElements = frame->nb_samples * frame->channels;
    
    NSMutableData *data = [NSMutableData dataWithLength:numElements * sizeof(float)];
    float scale = 1.0 / (float)INT16_MAX ;
    vDSP_vflt16((SInt16 *)audioData, 1, data.mutableBytes, 1, numElements);
    vDSP_vsmul(data.mutableBytes, 1, &scale, data.mutableBytes, 1, numElements);
    return [data copy];
}

static BOOL isFMT_S16(AVCodecContext *audio, int sample_o, int channels_o) {
    bool isSupported = NO;
    if (audio->sample_fmt == AV_SAMPLE_FMT_S16) {
        isSupported = sample_o == audio->sample_rate && channels_o == audio->channels;
    }
    return isSupported;
}

static AVFrame *convertFormat(AVFrame *frame_i, enum AVSampleFormat fmt_o, int sample_o, int channels_o, SwrContext *cachedContext) {
    SwrContext *swrContext = swr_alloc_set_opts(cachedContext,
                                                av_get_default_channel_layout(channels_o),
                                                fmt_o,
                                                sample_o,
                                                av_get_default_channel_layout(frame_i->channels),
                                                frame_i->format,
                                                frame_i->sample_rate,
                                                0,
                                                NULL);
    if (!swrContext) return NULL;
    if (swr_is_initialized(swrContext) == 0) {
        if (swr_init(swrContext)) {
            swr_free(&swrContext);
            return NULL;
        }
    }
    
    AVFrame *frame = av_frame_alloc();
    av_frame_copy(frame, frame_i);
    frame->format = fmt_o;
    frame->sample_rate = sample_o;
    frame->channels = channels_o;
    frame->best_effort_timestamp = frame_i->best_effort_timestamp;
    frame->pkt_duration = frame_i->pkt_duration;
    
    const int ratio = MAX(1, sample_o / frame_i->sample_rate) * MAX(1, channels_o / frame_i->channels) * 2;
    
    const int bufSize = av_samples_get_buffer_size(NULL,
                                                   channels_o,
                                                   frame_i->nb_samples * ratio,
                                                   fmt_o,
                                                   1);
    
    av_frame_make_writable(frame);
    if (frame->linesize[0] < bufSize) {
    }
    frame->linesize[0] = bufSize;
    frame->data[0] = realloc(frame->data[0], bufSize);
    Byte *outbuf[2] = { frame->data[0], 0 };
    
    frame->nb_samples  = swr_convert(swrContext,
                                     outbuf,
                                     frame_i->nb_samples * ratio,
                                     (const uint8_t **)frame_i->data,
                                     frame_i->nb_samples);
    
    
    if (frame->nb_samples < 0) {
        printf("fail resample audio");
        av_frame_free(&frame);
    }
    
    if (swrContext != cachedContext) {
        swr_free(&swrContext);
    }
    
    return frame;
}

@end

