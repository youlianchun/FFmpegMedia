//
//  AVObj.m
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/11/26.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "AVObj.h"

@implementation AVPacketObj
@synthesize data = _data;
@synthesize sign;

+(instancetype)bridge2ObjWith:(AVPacket *)data {
    AVPacketObj *obj;
    if (data) {
        obj = [self new];
        obj->_data = data;
    }
    return obj;
}
-(NSString *)typeStr {
    switch (_type) {
        case AVPacketType_audio:
            return @"AVPacketType_audio";
            break;
        case AVPacketType_video:
            return @"AVPacketType_video";
            break;
        case AVPacketType_suntitle:
            return @"AVPacketType_suntitle";
            break;
        default:
            return @"AVPacketType_unknown";
            break;
    }
}
-(void)dealloc {
    if (_data) {
        av_packet_free(&_data);
        av_free(_data);
    }
    _data = nil;
}
@end


@implementation AVFrameObjBase
@end

@implementation AVFrameObj
@synthesize data = _data;

+(instancetype)bridge2ObjWith:(AVFrame *)data {
    AVFrameObj *obj;
    if (data) {
        obj = [self new];
        obj->_data = data;
    }
    return obj;
}

-(void)dealloc {
    if (_data) {
        av_frame_free(&_data);
        av_free(_data);
    }
    _data = nil;
}
@end


@implementation AVSubtitleObj
@synthesize data = _data;

+(instancetype)bridge2ObjWith:(AVSubtitle *)data {
    AVSubtitleObj *obj;
    if (data) {
        obj->_data = data;
    }
    return obj;
}

-(void)dealloc {
    if (_data) {
        avsubtitle_free(_data);
//        av_free(_data);
    }
    _data = nil;
}

@end
