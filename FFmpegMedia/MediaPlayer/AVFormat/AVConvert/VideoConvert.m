//
//  VideoConvert.m
//  FFmpeg
//
//  Created by YLCHUN on 2018/11/5.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "VideoConvert.h"
#import "libavutil/imgutils.h"
#import "libswresample/swresample.h"
#import "libswscale/swscale.h"
#import "AVStreams.h"
#import "GLTexture.h"
#import "AVObj.h"
@implementation VideoConvert
{
    AVCodecCtx         *_codecCtx;
    struct SwsContext   *_swsContext;
}


+(instancetype)convertWithCodecCtx:(AVCodecCtx *)codecCtx {
    return [[self alloc] initWithCodecCtx:codecCtx];
}

-(instancetype)initWithCodecCtx:(AVCodecCtx *)codecCtx {
    if (self = [super init]) {
        _codecCtx = codecCtx;
    }
    return self;
}
-(void)dealloc {
    if (_swsContext) {
        sws_freeContext(_swsContext);
        _swsContext = NULL;
    }
    
    _codecCtx = nil;
}

-(struct SwsContext *)swsContext {
    if (_codecCtx && !_swsContext) {
        _swsContext = sws_getCachedContext(_swsContext,
                                           _codecCtx.context->width,//原始格式宽度
                                           _codecCtx.context->height,//原始格式高度
                                           _codecCtx.context->pix_fmt,//原始数据格式
                                           _codecCtx.context->width,//目标格式宽度
                                           _codecCtx.context->height,//目标格式高度
                                           AV_PIX_FMT_YUV420P,//目标数据格式
                                           SWS_FAST_BILINEAR,
                                           NULL, NULL, NULL);
    }
    return _swsContext;
}

-(void)receive:(void(^)(GLTexture *data, double duration, double position))receiveCB atAVObj:(AVFrameObjBase *)avObj {
    if (!receiveCB || !avObj || ![avObj isKindOfClass:[AVFrameObj class]]) return;
    AVFrameObj *frame = (AVFrameObj *)avObj;
    if (!frame.data->data[0]) return;
    
    enum AVPixelFormat pix_fmt = _codecCtx.context->pix_fmt;
    
    if (pix_fmt == AV_PIX_FMT_YUV420P || pix_fmt == AV_PIX_FMT_YUVJ420P) {
        
        GLTextureYUV_P *texture = [GLTextureYUV_P new];

        texture.Y = copyFrameData(frame.data->data[0],
                                  frame.data->linesize[0],
                                  frame.data->width,
                                  frame.data->height);
        texture.U = copyFrameData(frame.data->data[1],
                                  frame.data->linesize[1],
                                  frame.data->width / 2,
                                  frame.data->height / 2);
        texture.V = copyFrameData(frame.data->data[2],
                                  frame.data->linesize[2],
                                  frame.data->width / 2,
                                  frame.data->height / 2);
        texture.width = frame.data->width;
        texture.height = frame.data->height;

        double position = 0;
        double duration = 0;
        get_avFrame_time(frame.data, _codecCtx.timeBase, _codecCtx.fps, &position, &duration);

        receiveCB(texture, duration, position);
    } else {//TODO: check
        {//to AV_PIX_FMT_YUV420P
            AVFrame *newFrame = convertFormat(frame.data, AV_PIX_FMT_YUV420P, _codecCtx.context, self.swsContext);
            AVFrameObj *obj = [AVFrameObj bridge2ObjWith:newFrame];
            [self receive:receiveCB atAVObj:obj];
            av_frame_free(&newFrame);
            return;
        }
    
        {//to AV_PIX_FMT_RGB24
            AVFrame *newFrame = convertFormat(frame.data, AV_PIX_FMT_RGB24, _codecCtx.context, NULL);
            AVFrameObj *obj = [AVFrameObj bridge2ObjWith:newFrame];
            [self receive:receiveCB atAVObj:obj];
            
            GLTextureRGB *texture = [GLTextureRGB new];
//            texture.RGBA = [[NSData alloc] initWithBytes:frame->data[0] length:newFrame->width *newFrame->height];
            texture.RGBA = copyFrameData(frame.data->data[0],
                                         frame.data->linesize[0],
                                         frame.data->width,
                                         frame.data->height);
            texture.width = frame.data->width;
            texture.height = frame.data->height;
            
            av_frame_free(&newFrame);
           
            double position = 0;
            double duration = 0;
            get_avFrame_time(frame.data, _codecCtx.timeBase, _codecCtx.fps, &position, &duration);
            
            receiveCB(texture, duration, position);
        }
    }
}

static AVFrame *convertFormat(AVFrame *frame_i, enum AVPixelFormat pix_fmt_o, AVCodecContext *codec, struct SwsContext *cachedContext) {
    if (frame_i == NULL) {
        return NULL;
    }
    
    if (pix_fmt_o == AV_PIX_FMT_NONE) {
        pix_fmt_o = frame_i->format;
    }
    AVFrame *frame_o = av_frame_alloc();
    
    enum AVPixelFormat dist_pix_fmt = pix_fmt_o;
    int buffer_size = av_image_get_buffer_size(dist_pix_fmt,
                                               codec->width,
                                               codec->height,
                                               1);
    uint8_t *out_buffer = (uint8_t *)av_malloc(buffer_size * sizeof(uint8_t));
    //  向frame_o->填充数据
    int n = av_image_fill_arrays(frame_o->data,//目标->填充数据(frame_o)
                                 frame_o->linesize,//目标->每一行大小
                                 out_buffer,//目标->格式类型
                                 dist_pix_fmt,//目标->格式类型
                                 codec->width,
                                 codec->height,
                                 1);
    if (n < 0) {
        NSLog(@"av_image_fill_arrays error");
    }
    struct SwsContext *swsContext = sws_getCachedContext(cachedContext,
                                                         codec->width,//原始格式宽度
                                                         codec->height,//原始格式高度
                                                         codec->pix_fmt,//原始数据格式
                                                         codec->width,//目标格式宽度
                                                         codec->height,//目标格式高度
                                                         dist_pix_fmt,//目标数据格式
                                                         SWS_BICUBIC,
                                                         NULL, NULL, NULL);
    if (!swsContext) {
        av_frame_free(&frame_o);
        av_free(out_buffer);
        return NULL;
    }
    
    n = sws_scale(swsContext,//视频像素格式的上下文
                  (const uint8_t **)frame_i->data,//原始视频输入数据
                  frame_i->linesize,//原数据每一行的大小
                  0,//输入画面的开始位置，一般从0开始
                  frame_i->height,//原始数据的长度
                  frame_o->data,//输出的视频格式
                  frame_o->linesize);//输出的画面大小
    if (n < 0) {
        NSLog(@"sws_scale error");
    }
    if (swsContext != cachedContext) {
        sws_freeContext(swsContext);
    }
    
    return frame_o;
}

static NSData *copyFrameData(UInt8 *src, int linesize, int width, int height)
{
    width = MIN(linesize, width);
    NSMutableData *md = [NSMutableData dataWithLength: width * height];
    Byte *dst = md.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    return md;
}

void get_avFrame_time(AVFrame *frame, double timeBase, double fps, double *pos, double *dur) {
    if (frame == NULL) return;
    
    double position = frame->pts * timeBase;
    double duration = 0;
    const int64_t frameDuration = frame->pkt_duration;
    if (frameDuration) {
        duration = frameDuration * timeBase;
//        duration += frame->repeat_pict * timeBase * 0.5;
    } else {
        // sometimes, ffmpeg unable to determine a frame duration
        // as example yuvj420p stream from web camera
        duration = 1.0 / fps;
    }
    *pos = position;
    *dur = duration;
}
@end
