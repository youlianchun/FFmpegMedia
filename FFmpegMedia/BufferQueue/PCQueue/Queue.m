//
//  Queue.m
//  PCContainer
//
//  Created by YLCHUN on 2018/11/9.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "Queue.h"

@implementation Queue
{
    NSMutableArray *_arr;
}

+(instancetype)queue {
    return [[self alloc] init];
}

-(instancetype)init {
    if (self = [super init]) {
        _arr = [NSMutableArray array];
    }
    return self;
}

-(NSUInteger)count {
    return _arr.count;
}

-(void)push:(id)obj {
    [_arr addObject:obj];
}

-(id)pop {
    id obj = _arr.firstObject;
    [_arr removeObjectAtIndex:0];
    return obj;
}

-(void)clean {
    [_arr removeAllObjects];
}
@end
