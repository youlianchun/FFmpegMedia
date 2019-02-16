//
//  AVObj.h
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/11/26.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "libavformat/avformat.h"
#import "BufferQueueElement.h"

typedef enum AVPacketType {
    AVPacketType_unknown,
    AVPacketType_audio,
    AVPacketType_video,
    AVPacketType_suntitle,
} AVPacketType;

@interface AVPacketObj : NSObject <BufferQueueElement>
@property (nonatomic, readonly) AVPacket *data;
@property (nonatomic, assign) AVPacketType type;
@property (nonatomic, readonly) NSString *typeStr;
+(instancetype)bridge2ObjWith:(AVPacket *)data;
@end


@interface AVFrameObjBase : NSObject
@end

@interface AVFrameObj : AVFrameObjBase
@property (nonatomic, readonly) AVFrame *data;
+(instancetype)bridge2ObjWith:(AVFrame *)data;
@end

@interface AVSubtitleObj : AVFrameObjBase
@property (nonatomic, readonly) struct AVSubtitle *data;
+(instancetype)bridge2ObjWith:(AVSubtitle *)data;
@end

