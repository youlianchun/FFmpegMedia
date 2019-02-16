//
//  BufferQueue.h
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/12/15.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "BufferQueueElement.h"

@class BufferQueue;
@protocol BufferQueueDelegate<NSObject>
-(void)bufferQueue:(BufferQueue *_Nonnull)queue receiveOutElement:(void(^_Nonnull)(BQElement _Nonnull outElement))receiveElement atInElement:(BQElement _Nonnull)inElement;
@end


@interface BufferQueue : NSObject
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) BOOL isRuning;
-(instancetype)initWithDelegate:(id<BufferQueueDelegate>)delegate;
-(void)setSendThreshold:(NSUInteger)threshold;

-(void)start;
-(void)stop;

-(void)sendInElement:(BQElement)element;
-(BQElement)getOutElement;

-(void)clean;
@end
