//
//  BufferQueue.m
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/12/15.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "BufferQueue.h"
#import "PCQueue.h"

@interface BQNull : NSObject<BufferQueueElement>
@end
@implementation BQNull
@synthesize sign = _sign;
@end

@implementation BufferQueue
{
    __weak id<BufferQueueDelegate> _delegate;
    PCQueue<BQElement> *_inQueue;
    PCQueue<BQElement> *_outQueue;
    NSLock *_signLock;
    int _threadSign;
    int _sign;
    NSUInteger _threshold;
    dispatch_queue_t _queue;
}

@synthesize isRuning = _isRuning;

-(instancetype)initWithDelegate:(id<BufferQueueDelegate>)delegate {
    self = [super init];
    if (self) {
        _signLock = [NSLock new];
        _threshold = 1;
        _delegate = delegate;
        _queue = dispatch_queue_create("BufferQueue.receive.queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

-(void)createQueue {
    _inQueue = [PCQueue queueWithSize:_threshold];
    _outQueue = [PCQueue queueWithSize:_threshold];
}

-(void)freeQueue {
    [_inQueue free];
    [_outQueue free];
    _inQueue = nil;
    _outQueue = nil;
}

-(NSUInteger)count {
    return _outQueue.count;
}

-(void)start {//线程锁？
    if (_isRuning) return;
    _isRuning = true;
    [self createQueue];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self coredcThread];
    });
}

-(void)stop {//线程锁？
    if (!_isRuning) return;
    _isRuning = false;
    [self freeQueue];
}

-(void)coredcThread {
    _threadSign ++;
    int threadSign = _threadSign;
    while (_isRuning && threadSign == _threadSign) {
        @autoreleasepool {
            BQElement bqe = [_inQueue pop];
            if ([bqe isKindOfClass:[BQNull class]]) {
                [_outQueue push:bqe];
                continue;
            }
            __strong typeof(_delegate) delegate = _delegate;
            if (!delegate) break;
            
            dispatch_sync(_queue, ^{
                BOOL delegateReceiveEnd = NO;
                [delegate bufferQueue:self receiveOutElement:^(BQElement element) {
                    if (delegateReceiveEnd) {
                        NSAssert(false, @"此处禁止跨线程调用");
                        return;
                    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    element.sign = bqe.sign;
#pragma clang diagnostic pop
                    [self->_outQueue push:element];
                } atInElement:bqe];
                delegateReceiveEnd = YES;
            });
            NSLog(@"bufferQueue: %@, %ld, %ld", NSStringFromClass([_delegate class]), _inQueue.count, _outQueue.count);
        }
    }
}

-(void)upsateSign {
    [_signLock lock];
    _sign ++;
    [_signLock unlock];
}

-(int)getSign {
    [_signLock lock];
    int sign = _sign;
    [_signLock unlock];
    return sign;
}

-(void)sendInElement:(BQElement)element {
    if (element == nil) {
        element = [BQNull new];
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
     element.sign = [self getSign];
#pragma clang diagnostic pop
    [_inQueue push:element];
}

-(BQElement)getOutElement {
    BQElement element = [_outQueue pop];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (element.sign != [self getSign]) {
        return [self getOutElement];
    }
#pragma clang diagnostic pop
    if ([element isKindOfClass:[BQNull class]]) {
        return nil;
    }
    return element;
}

-(void)clean {
    [self upsateSign];
    [_inQueue clean];
    [_outQueue clean];
}

-(void)setSendThreshold:(NSUInteger)threshold {
    threshold = MAX(threshold, 1);
    _threshold = threshold;
    [_inQueue setPushSize:threshold];
    [_outQueue setPushSize:threshold];
}


@end

