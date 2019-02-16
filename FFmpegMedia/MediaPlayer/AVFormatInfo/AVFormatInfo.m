////
////  AVFormatInfo.m
////  FFmpeg
////
////  Created by YLCHUN on 2018/11/2.
////  Copyright © 2018年 YLCHUN. All rights reserved.
////
//
//#import "AVFormatInfo_private.h"
//
//static NSString *toString(const char *cString) {
//    return [NSString stringWithCString:cString encoding:NSUTF8StringEncoding];
//}
//
//static NSString *removePrefix(NSString *string, NSString *prefix) {
//    if (prefix.length >0 && [string hasPrefix:prefix])
//        string = [string substringFromIndex:prefix.length];
//    return string;
//}
//
//static NSString *stream_info(AVStream *stream) {
//    NSMutableString *mStr = [NSMutableString string];
//    AVDictionaryEntry *lang = av_dict_get(stream->metadata, "language", NULL, 0);
//    if (lang && lang->value) {
//        [mStr appendFormat:@"%s ", lang->value];
//    }
//    
//    AVCodecContext *codecCtx = get_codec_context(stream);
//    if (codecCtx != NULL) {
//        char buf[256];
//        avcodec_string(buf, sizeof(buf), codecCtx, 1);
//        avcodec_free_context(&codecCtx);
//        
//        NSString *codecString = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
//        [mStr appendString:codecString];
//    }
//    return [mStr copy];
//}
//
//static NSArray<AVStreamInfo*> *streams_info(AVFormatContext *formatCtx, enum AVMediaType codecType, NSString *(^process)(NSString *desc)) {
//    NSMutableArray *infos = [NSMutableArray array];
//
//    for (NSInteger i = 0; i < formatCtx->nb_streams; ++i){
//        if (codecType == formatCtx->streams[i]->codecpar->codec_type){
//            
//            AVStream *stream = formatCtx->streams[i];
//            NSString *desc = stream_info(stream);
//            if (process) {
//                desc = process(desc);
//            }
//            
//            AVStreamInfo *info = [AVStreamInfo infoWithStream:i desc:desc];
//            [infos addObject:info];
//        }
//    }
//    return infos;
//}
//
//
//@implementation AVStreamInfo
//@synthesize desc = _desc;
//@synthesize stream = _stream;
//
//+(instancetype)infoWithStream:(NSUInteger)stream desc:(NSString*)desc {
//    AVStreamInfo *info = [self new];
//    info->_desc = desc;
//    info->_stream = stream;
//    return info;
//}
//
//@end
//
//@implementation AVFormatInfo
//@synthesize format = _format;
//@synthesize bitrate = _bitrate;
//@synthesize metadata = _metadata;
//@synthesize video = _video;
//@synthesize audio = _audio;
//@synthesize subtitle = _subtitle;
//
//+(instancetype)infoWithFormat:(AVFormatContext *)formatCtx {
//    if (formatCtx == NULL) return nil;
//    
//    AVFormatInfo *info = [AVFormatInfo new];
//    
//    info->_format = toString(formatCtx->iformat->name);
//    if (formatCtx->bit_rate) {
//        info->_bitrate = formatCtx->bit_rate;
//    }
//    
//    if (formatCtx->metadata) {
//        NSMutableDictionary *mDict = [NSMutableDictionary dictionary];
//        AVDictionaryEntry *tag = NULL;
//        while((tag = av_dict_get(formatCtx->metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
//            NSString *key = toString(tag->key);
//            mDict[key] = toString(tag->value);
//        }
//        info->_metadata = [mDict copy];
//    }
//    
//    info->_video = streams_info(formatCtx, AVMEDIA_TYPE_VIDEO, ^NSString *(NSString *desc) {
//        return removePrefix(desc, @"Video: ");
//    });
//    
//    info->_audio = streams_info(formatCtx, AVMEDIA_TYPE_AUDIO, ^NSString *(NSString *desc) {
//        return removePrefix(desc, @"Audio: ");
//    });
//    
//    info->_subtitle = streams_info(formatCtx, AVMEDIA_TYPE_SUBTITLE, ^NSString *(NSString *desc) {
//        return removePrefix(desc, @"Subtitle: ");
//    });
//    
//    return info;
//}
//@end
