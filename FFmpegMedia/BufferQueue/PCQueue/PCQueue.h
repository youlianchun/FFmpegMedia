//
//  PCQueue.h
//  PCContainer
//
//  Created by YLCHUN on 2018/11/6.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PCQueue<Element> : NSObject
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) NSUInteger threshold;
+(instancetype)queueWithSize:(NSUInteger)size;
-(void)setPushSize:(NSUInteger)size;
-(void)push:(Element)obj;
-(Element)pop;
-(void)clean;
-(void)clean:(void( ^ _Nullable )(void))action;
-(void)free;
@end

NS_ASSUME_NONNULL_END
