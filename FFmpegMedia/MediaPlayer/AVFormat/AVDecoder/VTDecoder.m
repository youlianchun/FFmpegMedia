//
//  VTDecoder.m
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/11/12.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "VTDecoder.h"
#import "libavformat/avformat.h"
#import "libavformat/avc.h"
#import <CoreMedia/CoreMedia.h>
#import "AVStreams.h"
#import "AVObj.h"

#import "GLTexture.h"
@import VideoToolbox;


typedef void(^VTDecodeCallback)(OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime timeStamp, CMTime duration);

static void VTDecoderCallback(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration) {
    VTDecodeCallback callback = (__bridge VTDecodeCallback)(sourceFrameRefCon);
    callback(status, infoFlags, CVBufferRetain(imageBuffer), presentationTimeStamp, presentationDuration);
}

@implementation VTDecoder
{
    OSType _pixelFormatType;
    VTDecompressionSessionRef _session;
    CMFormatDescriptionRef _formatDescRef;
    AVCodecCtx *_codecCtx;
}

+(instancetype)decoderWithCodecCtx:(AVCodecCtx *)codecCtx {
    if ([self isSupport:codecCtx]) {
        return [[self alloc] initWithCodecCtx:codecCtx];
    }
    return nil;
}

-(instancetype)initWithCodecCtx:(AVCodecCtx *)codecCtx {
    if (self = [super init]) {
        _codecCtx = codecCtx;
        _pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    }
    return self;
}

-(void)setup {
    _session = [self createsSession:_codecCtx.parameters];
}

-(VTDecompressionSessionRef)createsSession:(AVCodecParameters *)codecpar
{
    if(!codecpar) return NULL;
    
    _formatDescRef = vtbformat_init(codecpar);
    if (_formatDescRef == NULL) {
        NSLog(@"_formatDescRef null");
    }
    
    NSDictionary *destAttrs = @{(id)kCVPixelBufferOpenGLESCompatibilityKey  :@(YES),
                                (id)kCVPixelBufferPixelFormatTypeKey        :@(_pixelFormatType),
                                (id)kCVPixelBufferWidthKey                  :@(codecpar->width),
                                (id)kCVPixelBufferHeightKey                 :@(codecpar->height),
                                };
    
    VTDecompressionOutputCallbackRecord outputCallback;
    outputCallback.decompressionOutputCallback = VTDecoderCallback;
    outputCallback.decompressionOutputRefCon = (__bridge void * _Nullable)(self);
    
    VTDecompressionSessionRef session = NULL;
    OSStatus status = VTDecompressionSessionCreate(
                                          kCFAllocatorDefault,
                                          _formatDescRef,
                                          NULL,
                                          (__bridge CFDictionaryRef)(destAttrs),
                                          &outputCallback,
                                          &session);

    if (status != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Error %@", [error description]);
    }
    
    return session;
}


-(BOOL)receiveTexture:(void(^)(GLTexture *texture))receiveCB atPacket:(AVPacketObj *)packet {
    if (!packet.data || !_session || !receiveCB) return NO;
    
    VTDecodeCallback decodeback = ^(OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime timeStamp, CMTime duration) {
        
        if (status != noErr) return;
        
        if (kVTDecodeInfo_FrameDropped & infoFlags) return ;//droped
        
        OSType format_type = CVPixelBufferGetPixelFormatType(imageBuffer);
        if (format_type != self->_pixelFormatType) {
            //format_type error
            return;
        }
        
        GLTextureYUV_SP *yuv = [GLTextureYUV_SP new];

        if (CVPixelBufferIsPlanar(imageBuffer)) {
            yuv.width  = (int)CVPixelBufferGetWidthOfPlane(imageBuffer, 0);
            yuv.height = (int)CVPixelBufferGetHeightOfPlane(imageBuffer, 0);
        } else {
            yuv.width  = (int)CVPixelBufferGetWidth(imageBuffer);
            yuv.height = (int)CVPixelBufferGetHeight(imageBuffer);
        }
        
        if (CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly) == kCVReturnSuccess) {
            uint8_t *y_frame = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
            size_t y_size = yuv.width * yuv.height;
            yuv.Y = [[NSData alloc] initWithBytes:y_frame length:y_size];
            
            size_t uv_size = y_size / 2;
            uint8_t *uv_frame = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
            yuv.UV = [[NSData alloc] initWithBytes:uv_frame length:uv_size];
            
            CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
            CVBufferRelease(imageBuffer);
        }else {
            
            return;
        }
        receiveCB(yuv);
    };
    
    
    //TODO: create sampleBuffer
    CMSampleBufferRef sampleBuffer = createSampleBufferFrom(_formatDescRef, packet.data->data, packet.data->size);
    if (!sampleBuffer) return NO;
    
    VTDecodeFrameFlags flags = 0;
    VTDecodeInfoFlags infoFlags = 0;
    // 解码过程默认是同步操作。
    OSStatus status = VTDecompressionSessionDecodeFrame(_session,
                                                        sampleBuffer,
                                                        flags,
                                                        (__bridge void * _Nullable)(decodeback),
                                                        &infoFlags);
    CFRelease(sampleBuffer);
    if (status != noErr) {
        
    }
    return YES;
}

+(BOOL)isSupport:(AVCodecCtx *)codecCtx {
    if (!codecCtx) return NO;
    if (codecCtx.type != CodecCtxType_video) {
        return NO;
    }
    enum AVCodecID codec_id = codecCtx.context->codec_id;
    CMVideoCodecType format_id = getVTCodecTypeIfSuppord(codec_id);
    return format_id > 0;
}


static CMFormatDescriptionRef createFormatDescriptionFromCodecData(CMVideoCodecType format_id, int width, int height, const uint8_t *extradata, int extradata_size)
{
    NSDictionary *parDict = @{(__bridge NSString *)kCVImageBufferPixelAspectRatioHorizontalSpacingKey:@(0),
                              (__bridge NSString *)kCVImageBufferPixelAspectRatioVerticalSpacingKey:@(0),
                              };
    
    NSData *extraData = [[NSData alloc] initWithBytes:extradata length:extradata_size];
    NSDictionary *atomsDict;
    switch (format_id) {
        case kCMVideoCodecType_H264:
            atomsDict = @{@"avcC": extraData};
            break;
        case kCMVideoCodecType_HEVC:
            atomsDict = @{@"hvcC": extraData};
            break;
        case kCMVideoCodecType_MPEG4Video:
            atomsDict = @{@"esds": extraData};
            break;
        default:
            atomsDict = @{};
            break;
    }
    
    NSDictionary *extensions = @{(__bridge NSString *)kCMFormatDescriptionExtension_ChromaLocationBottomField:@"left",
                                 (__bridge NSString *)kCMFormatDescriptionExtension_ChromaLocationTopField:@"left",
                                 (__bridge NSString *)kCMFormatDescriptionExtension_FullRangeVideo:@(NO),
                                 (__bridge NSString *)kCMFormatDescriptionExtension_PixelAspectRatio:parDict,
                                 (__bridge NSString *)kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms:atomsDict,
                                 };
    
    CMFormatDescriptionRef fmt_desc = NULL;
    OSStatus status = CMVideoFormatDescriptionCreate(NULL, format_id, width, height, (__bridge CFDictionaryRef _Nullable)(extensions), &fmt_desc);
    
    if (status == 0)
        return fmt_desc;
    else
        return NULL;
}


static CMSampleBufferRef createSampleBufferFrom(CMFormatDescriptionRef fmt_desc, void *demux_buff, size_t demux_size)
{
    CMBlockBufferRef newBBufOut = NULL;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL, demux_buff, demux_size, kCFAllocatorNull, NULL, 0, demux_size, FALSE, &newBBufOut);
    
    CMSampleBufferRef sBufOut = NULL;
    if (!status) {
        status = CMSampleBufferCreate(NULL, newBBufOut, TRUE, 0, 0, fmt_desc, 1, 0, NULL, 0, NULL, &sBufOut);
    }
    
    if (newBBufOut)
        CFRelease(newBBufOut);
    if (status == 0) {
        return sBufOut;
    } else {
        return NULL;
    }
}


static CMVideoCodecType getVTCodecTypeIfSuppord(enum AVCodecID codec) {
    CMVideoCodecType codecType = 0;
    switch (codec) {
        case AV_CODEC_ID_HEVC:
            if (@available(iOS 11.0, *)) {
                if (VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
                    codecType = kCMVideoCodecType_HEVC;
                }
            }
            break;
        case AV_CODEC_ID_H264:
            codecType = kCMVideoCodecType_H264;
            break;
        case AV_CODEC_ID_MPEG4://TODO: code
            codecType = kCMVideoCodecType_MPEG4Video;
            break;
        default:
            break;
    }
    return codecType;
}

static CMFormatDescriptionRef vtbformat_init(AVCodecParameters *codecpar)
{
    int width           = codecpar->width;
    int height          = codecpar->height;
    int extrasize       = codecpar->extradata_size;
    int codec           = codecpar->codec_id;
    uint8_t* extradata  = codecpar->extradata;
    
    if (width < 0 || height < 0) {
        return NULL;
    }
    
    if (extrasize < 7 || extradata == NULL) {
        //  printf("%s - avcC or hvcC atom data too small or missing", __FUNCTION__);
        return NULL;
    }
    
    CMVideoCodecType format_id = getVTCodecTypeIfSuppord(codec);
    if (format_id == 0) return NULL;
    
    CMFormatDescriptionRef formatDescRef = NULL;
    if (extradata[0] == 1) {
        formatDescRef = createFormatDescriptionFromCodecData(format_id, width, height, extradata, extrasize);
    } else {
        if ((extradata[0] == 0 && extradata[1] == 0 && extradata[2] == 0 && extradata[3] == 1) ||
            (extradata[0] == 0 && extradata[1] == 0 && extradata[2] == 1)) {
            AVIOContext *pb;
            if (avio_open_dyn_buf(&pb) < 0) {
                return NULL;
            }
            
            ff_isom_write_avcc(pb, extradata, extrasize);
            extradata = NULL;
            
            extrasize = avio_close_dyn_buf(pb, &extradata);
            
            formatDescRef = createFormatDescriptionFromCodecData(format_id, width, height, extradata, extrasize);
            av_free(extradata);
        } else {
            //            printf("%s - invalid avcC atom data", __FUNCTION__);
            return NULL;
        }
    }
    return formatDescRef;
}

@end

#import "AVFrames.h"

@implementation VTDecoder(vf)

-(BOOL)decodePacket:(AVPacketObj *)packet callback:(void(^)(VideoFrame *frame))callback {
    return [self receiveTexture:^(GLTexture * _Nonnull texture) {
        double position = 0, duration = 0;
        get_avPtkFrame_time(packet.data, self->_codecCtx.timeBase, self->_codecCtx.fps, 0, &position, &duration);
        VideoFrame *frame = [VideoFrame frameWithTexture:texture pos:position dur:duration];
        callback(frame);
    } atPacket:packet];
}

static void get_avPtkFrame_time(AVPacket *packet, double timeBase, double fps, double frame_repeat_pict, double *pos, double *dur) {
    if (packet == NULL) return;
    
    double pts = packet->pts;
    if (packet->pts == AV_NOPTS_VALUE) {
        pts = packet->dts;
    }
    double position = pts * timeBase;
    double duration = 0;
    const int64_t frameDuration = packet->duration;
    if (frameDuration) {
        duration = frameDuration * timeBase;
        duration += frame_repeat_pict * timeBase * 0.5;
    } else {
        // sometimes, ffmpeg unable to determine a frame duration
        // as example yuvj420p stream from web camera
        duration = 1.0 / fps;
    }
    *pos = position;
    *dur = duration;
}
@end
