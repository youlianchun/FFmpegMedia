//
//  Queue.h
//  PCContainer
//
//  Created by YLCHUN on 2018/11/9.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Queue<Element> : NSObject
@property (nonatomic, readonly) NSUInteger count;
+(instancetype)queue;
-(void)push:(Element)obj;
-(Element)pop;
-(void)clean;
@end

NS_ASSUME_NONNULL_END
