//
//  BufferQueueElement.h
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/12/15.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol BufferQueueElement <NSObject>
@property (nonatomic, assign) int sign __attribute((deprecated("禁止使用sign")));
@end

typedef id<BufferQueueElement> BQElement;


