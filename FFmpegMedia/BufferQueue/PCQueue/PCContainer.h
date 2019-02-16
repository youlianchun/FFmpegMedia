//
//  PCContainer.h
//  PCContainer
//
//  Created by YLCHUN on 2018/11/9.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//注意：事件嵌套调用将导致死锁！

@interface PCContainer<PCContext> : NSObject
typedef BOOL(^PCContainerAction)(void);
typedef BOOL(^PCContainerCondition)(PCContext context);

@property (nonatomic, readonly) BOOL didFree;

/**
 创建生产者消费者容器
 
 @param context 上下文，需要使用者持有，用于容器condition
 @param canConsume 可消费条件
 @param canProduce 可生产条件
 @return 容器实例
 */
+(instancetype)containerWithContext:(PCContext)context produceCondition:(PCContainerCondition)canProduce consumeCondition:(PCContainerCondition)canConsume;

/**
 触发生产事件
 
 @param produce 生产事件内容；事件成功return YES，失败return NO
 */
-(void)produce:(PCContainerAction)produce;

/**
 触发消费事件
 
 @param consume 消费事件内容；事件成功return YES，失败return NO
 */
-(void)consume:(PCContainerAction)consume;

/**
 触发自定义操作事件
 
 @param action 自定义操作事件内容
 */
-(void)customOp:(void(^)(void))action;

/**
 触发释放操作事件，执行后将结束所有等待中的线程，且容器进入不可用状态
 
 @param action 释放事件内容
 */
-(void)free:(void(^ _Nullable)(void))action;

@end

NS_ASSUME_NONNULL_END


