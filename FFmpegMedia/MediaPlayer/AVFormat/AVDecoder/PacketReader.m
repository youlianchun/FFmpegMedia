//
//  PacketReader.m
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/12/15.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "PacketReader.h"
#import "AVFormatObj.h"
#import "AVFrames.h"
#import "AVObj.h"

@implementation PacketReader
{
    AVFormatObj *_format;
    int _threadSign;
    BOOL _isRuning;
    __weak id<PacketReaderDelegate> _delegate;
    dispatch_queue_t _queue;
}

-(instancetype)initWithFormat:(AVFormatObj *)format delegate:(__weak id<PacketReaderDelegate>)delegate {
    if (self = [super init]) {
        _format = format;
        _delegate = delegate;
        _isRuning = NO;
        _queue = dispatch_queue_create("packet.reader.queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

-(void)start {
    if (_isRuning) return;
    _isRuning = YES;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self readThread];
    });
}

-(void)stop {
    if (!_isRuning) return;
    _isRuning = NO;
}

-(AVPacketObj *)readPacket {
    return [_format readPacket];
}

-(void)readThread {
    int threadSign = ++_threadSign;
    while (_isRuning && threadSign == _threadSign) {
        @autoreleasepool {
            AVPacketObj *obj = [self readPacket];
            dispatch_sync(_queue, ^{
                [self->_delegate didDeceive:obj atReader:self];
            });
            if (!obj) {
                break;
            }
        }
    }
    if (threadSign == _threadSign) {
        _isRuning = NO;
    }
}

@end

