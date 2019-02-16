//
//  AVStreams.h
//  FFmpeg
//
//  Created by YLCHUN on 2018/11/7.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVFormatObj.h"
#import "AVCodecCtx.h"

@class AVPacketObj, AVFrameObj;
NS_ASSUME_NONNULL_BEGIN

@interface AVBaseStream : NSObject
@property (nonatomic, readonly) AVCodecCtx *codecCtx;
@property (nonatomic, readonly) NSInteger streamIdx;
@property (nonatomic, readonly) double timeBase;
@property (nonatomic, readonly) double fps;
@property (nonatomic, readonly) BOOL didOpen;

-(instancetype)initWithFormat:(AVFormatObj *)format;


-(BOOL)openCodec;
-(void)closeCodec;

-(BOOL)changeStreamIdx:(NSInteger)index;
-(void)setPosition: (double)seconds;

@end

@interface AudioStream : AVBaseStream
@end

@interface VideoStream : AVBaseStream
@end

@interface SubtitleStream : AVBaseStream
@property (nonatomic, readonly) double timeBase NS_UNAVAILABLE;
@property (nonatomic, readonly) double fps NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
