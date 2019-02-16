//
//  AVFormatHandler.h
//  FFmpeg
//
//  Created by YLCHUN on 2018/11/7.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "libavformat/avformat.h"
@class AVPacketObj;
NS_ASSUME_NONNULL_BEGIN

@interface AVFormatObj : NSObject
@property (nonatomic, readonly) AVFormatContext *context;
@property (nonatomic, readonly) BOOL didOpen;
@property (nonatomic, readonly) BOOL isNetworkPath;
@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) double duration;
-(instancetype)initWithPath:(NSString *)path interruptCallback:(BOOL(^)(void))callback;
-(BOOL)open;
-(void)close;

-(void)seek:(int)streamIdx time:(int64_t)ts;
-(AVPacketObj *)readPacket;
@end

NS_ASSUME_NONNULL_END
