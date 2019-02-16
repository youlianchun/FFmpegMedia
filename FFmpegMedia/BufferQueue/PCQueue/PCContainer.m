//
//  PCContainer.m
//  PCContainer
//
//  Created by YLCHUN on 2018/11/9.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "PCContainer.h"

@implementation PCContainer
{
    NSCondition *_condition;
    PCContainerAction _canProduce;
    PCContainerAction _canConsume;
}
@synthesize didFree = _didFree;

+(instancetype)containerWithContext:(id)context produceCondition:(PCContainerCondition)canProduce consumeCondition:(PCContainerCondition)canConsume {
    BOOL hasContext = context != nil;
    __weak id wcontext = context;
    return [[self alloc] initWithConsumeCondition:^BOOL{
        __strong id context = wcontext;
        if (hasContext && !context) return NO;
        return canConsume(context);
    } produceCondition:^BOOL{
        __strong id context = wcontext;
        if (hasContext && !context) return NO;
        return canProduce(context);
    }];
}

-(instancetype)initWithConsumeCondition:(PCContainerAction)canConsume produceCondition:(PCContainerAction)canProduce {
    self = [super init];
    if (self) {
        _canProduce = canProduce;
        _canConsume = canConsume;
        _condition = [[NSCondition alloc] init];
        _didFree = NO;
    }
    return self;
}

-(void)produce:(PCContainerAction)produce {
    
    [_condition lock];
    
    while (!_didFree && !_canProduce()) {
        [_condition wait];
    }
    
    if (!_didFree && produce()){
        [_condition signal];
    }
    
    [_condition unlock];
}

-(void)consume:(PCContainerAction)consume {
    
    [_condition lock];
    
    while (!_didFree && !_canConsume()) {
        [_condition wait];
    }
    
    if (!_didFree && consume()) {
        [_condition signal];
    }
    
    [_condition unlock];
}

-(void)customOp:(void(^)(void))action {
    if (!action) return;
    
    [_condition lock];
    if (!_didFree) {
        action();
        [_condition signal];
    }
    [_condition unlock];
}

-(void)free:(void(^)(void))action {
    [_condition lock];
    if (!_didFree) {
        _didFree = YES;
        !action?:action();
        [_condition broadcast];
    }
    [_condition unlock];
}

-(void)dealloc {
    [self free:NULL];
}

@end
