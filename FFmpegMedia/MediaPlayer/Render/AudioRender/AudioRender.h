//
//  AudioRender.h
//  FFmpegTest
//
//  Created by YLCHUN on 2018/10/31.
//  Copyright © 2018年 times. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^AudioRenderFillDataCallback)(float *fillData, UInt32 numFrames, UInt32 numChannels);

@interface AudioRender : NSObject
@property (readonly, assign) UInt32             channels;
@property (readonly, assign) Float64            samplingRate;
@property (readonly, assign) BOOL               playing;

- (void)setFillDataCallback:(AudioRenderFillDataCallback)fillDataCallback;
- (void)setFrameDataFillback:(NSData*(^)(void))fillback;
- (BOOL) play;
- (void) pause;

- (BOOL) activate;
- (void) deactivate;

+(instancetype)sharedInstance;
@end
