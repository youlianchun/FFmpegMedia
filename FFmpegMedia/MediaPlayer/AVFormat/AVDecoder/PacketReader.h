//
//  PacketReader.h
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/12/15.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVPacketObj, PacketReader, AVFormatObj;
NS_ASSUME_NONNULL_BEGIN
@protocol PacketReaderDelegate<NSObject>
-(void)didDeceive:(AVPacketObj *)packet atReader:(PacketReader*)reader;
@end

@interface PacketReader : NSObject
-(instancetype)initWithFormat:(AVFormatObj *)format delegate:(__weak id<PacketReaderDelegate>)delegate;
-(void)start;
-(void)stop;
@end
NS_ASSUME_NONNULL_END
