//
//  AVConvert.h
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/12/14.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>
@class AVCodecCtx, AVFrameObjBase;

@protocol AVConvert <NSObject>

+(instancetype)convertWithCodecCtx:(AVCodecCtx *)codecCtx;
-(void)receive:(void(^)(id data, double duration, double position))receiveCB atAVObj:(AVFrameObjBase *)avObj;

@end
