//
//  PCQueue.m
//  PCContainer
//
//  Created by YLCHUN on 2018/11/6.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "PCQueue.h"
#import "PCContainer.h"
#import "Queue.h"

@implementation PCQueue
{
    Queue *_queue;
    PCContainer *_pcc;
    NSUInteger _size;
}
@synthesize threshold = _size;

+(instancetype)queueWithSize:(NSUInteger)size {
    return [[self alloc] initWithSize:size];
}

-(instancetype)initWithSize:(NSUInteger)size {
    self = [super init];
    if (self) {
        _size = size;
        _queue = [Queue queue];
        _pcc = [PCContainer<PCQueue *> containerWithContext:self produceCondition :^BOOL(PCQueue *  _Nonnull context) {
            return context -> _size == 0 || context->_queue.count < context -> _size;
        } consumeCondition:^BOOL(PCQueue *  _Nonnull context) {
            return context->_queue.count > 0;
        }];
    }
    return self;
}

-(void)dealloc {
    [self free];
    _queue = nil;
    _pcc = nil;
}

-(NSUInteger)count {
    __block NSUInteger count;
    [_pcc customOp:^{
        count = self->_queue.count;
    }];
    return count;
}

-(void)setPushSize:(NSUInteger)size {
    if (_size == size) return;
    
    [_pcc customOp:^{
        self->_size = size;
    }];
}

-(void)push:(id)obj {
    [_pcc produce:^BOOL{
        [self->_queue push:obj];
        return YES;
    }];
}

-(id)pop {
    __block id obj;
    [_pcc consume:^BOOL{
        obj = [self->_queue pop];
        return YES;
    }];
    return obj;
}

-(void)clean {
    [self clean:nil];
}

-(void)clean:(void(^)(void))action {
    [_pcc customOp:^{
        [self->_queue clean];
        !action?:action();
    }];
}

-(void)free {
    [_pcc free:^{
        [self->_queue clean];
    }];
}

@end

