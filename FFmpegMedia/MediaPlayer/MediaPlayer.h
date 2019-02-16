//
//  MediaPlayer.h
//  FFmpeg
//
//  Created by YLCHUN on 2018/11/7.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import <Foundation/Foundation.h>

@class UIView, MediaPlayer;

NS_ASSUME_NONNULL_BEGIN

@interface MediaPlayer : NSObject
@property (nonatomic, readonly) UIView *view;
@property (nonatomic, readonly) double duration;
-(instancetype)initWithPath:(NSString *)path;
-(void)prepare;
-(void)play;
-(void)pause;

-(void)setEndPlayCB:(void(^)(void))dndPlayCB;
-(void)setProgressCB:(void(^)(double progress))progressCB;
-(void)setProgress:(double)progress;
@end

NS_ASSUME_NONNULL_END
