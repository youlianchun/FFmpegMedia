//
//  SwrConvert.h
//  FFmpeg
//
//  Created by YLCHUN on 2018/11/5.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVConvert.h"
@class AVCodecCtx, AVFrameObj;
@interface AudioConvert : NSObject<AVConvert>
-(void)receive:(void(^)(NSData *data, double duration, double position))receiveCB atAVObj:(AVFrameObj *)avObj;
@end


