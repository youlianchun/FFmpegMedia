//
//  FormatDecoder.h
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/12/14.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DecoderType.h"
@class AVFormatObj, AudioFrame, VideoFrame, SubtitleFrame;

@interface FormatDecoder : NSObject
@property (nonatomic, readonly) double videoWidth;
@property (nonatomic, readonly) double videoHeight;
@property (nonatomic, readonly) VideoTextureType videoTextureType;

-(instancetype)initWithVideoFormat:(AVFormatObj*)format;
-(void)open;
-(void)close;

-(void)seekPosition:(double)seconds decodeMore:(BOOL)decodeMore;
-(void)decodeMore;

-(AudioFrame *)getAudioFrame;
-(VideoFrame *)getVideoFrame;
-(SubtitleFrame *)getSutitleFrame;

@end
