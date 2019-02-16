//
//  SubtitleConvert.h
//  FFmpeg
//
//  Created by YLCHUN on 2018/11/5.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "libavformat/avformat.h"
#import "AVConvert.h"

@interface SubtitleConvert : NSObject<AVConvert>
-(void)receive:(void(^)(NSString *data, double duration, double position))receiveCB atAVObj:(AVFrameObjBase *)avObj;
@end
