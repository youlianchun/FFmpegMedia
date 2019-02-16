//
//  MediaPlayer.m
//  FFmpeg
//
//  Created by YLCHUN on 2018/11/7.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "MediaPlayer.h"
#import "AVStreams.h"
#import "AudioRender.h"
#import "AVFrames.h"
#import "GLRenderView.h"
#import "FormatDecoder.h"

@interface MediaPlayerHud : NSObject
@end

@implementation MediaPlayerHud
{
    UIActivityIndicatorView *_hud;
}

-(instancetype)initWithHudInView:(UIView *)view {
    self = [super init];
    if (self) {
        _hud = createHud(view);
    }
    return self;
}

static UIActivityIndicatorView *createHud(UIView *inView) {
    UIActivityIndicatorView *hud = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleWhiteLarge];
    hud.hidesWhenStopped = YES;
    
    [inView addSubview:hud];
    hud.translatesAutoresizingMaskIntoConstraints = NO;
    [inView addConstraint:[NSLayoutConstraint constraintWithItem:hud attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:inView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [inView addConstraint:[NSLayoutConstraint constraintWithItem:hud attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:inView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    
    return hud;
}

-(void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self didShow]) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        [self performSelector:@selector(showHud) withObject:nil afterDelay:0.1];
        }
    });
}


-(void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self didShow]) {
            [self hideHud];
        }
    });
}

-(BOOL)didShow {
    return _hud.animating;
}

-(void)showHud {
    [_hud startAnimating];
}
-(void)hideHud {
    [_hud stopAnimating];
}


@end

@implementation MediaPlayer
{
    NSString *_path;
    AVFormatObj *_format;
    FormatDecoder *_formatDecoder;

    AudioFrame *_currentAudioFrame;
    
    GLRenderView *_renderView;
    
    int _renderId;
    void(^_progressCB)(double progress);
    void(^_endPlayCB)(void);
    
    MediaPlayerHud *_hud;
}
@synthesize view = _view;

-(instancetype)initWithPath:(NSString *)path {
    if (self = [super init]) {
        _path = path;
        _renderId = 0;
    }
    return self;
}

-(UIView *)view {
    if (!_view) {
        _view = [UIView new];
        _view.backgroundColor = [UIColor clearColor];
        _hud = [[MediaPlayerHud alloc] initWithHudInView:_view];
    }
    return _view;
}

-(double)duration {
    return _format.duration;
}

-(void)prepare{
     dispatch_async(dispatch_get_global_queue(0, 0), ^{
         self->_format = [[AVFormatObj alloc] initWithPath:self->_path interruptCallback:^BOOL{
             return NO;
         }];
         self->_formatDecoder = [[FormatDecoder alloc] initWithVideoFormat:self->_format];
         
         if ([self->_format open]) {
             [[AudioRender sharedInstance] activate];
             [self->_formatDecoder open];
             
             GLTextureType gltt = toTextureType(self->_formatDecoder.videoTextureType);
             CGSize videoSize = CGSizeMake(self->_formatDecoder.videoWidth, self->_formatDecoder.videoHeight);
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 self->_renderView = [[GLRenderView alloc] initWithFrame:UIScreen.mainScreen.bounds textureType:gltt size:videoSize];
                 [self setProgress:0];
                 [self layoutRenderView:self->_renderView];
             });
         }
     });
}

static GLTextureType toTextureType(VideoTextureType type) {
    switch (type) {
        case VideoTextureType_yuv420sp:
            return GLTextureTypeYUV420SP;
        case VideoTextureType_yuv420p:
            return GLTextureTypeYUV420P;
        default:
            return GLTextureTypeRGB;
    }
}

-(void)layoutRenderView:(GLRenderView *)view {
    [self.view insertSubview:view atIndex:0];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [view.superview addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:view.superview attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
    [view.superview addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:view.superview attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
    [view.superview addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:view.superview attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [view.superview addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
}

-(void)play {
    [self _play];
}

-(void)pause {
    [self _pause];
}

-(void)_play {
    AudioRender *render = [AudioRender sharedInstance];
    if (render.playing) return;
    
    [_formatDecoder decodeMore];
    
    __weak typeof(self) wself = self;
    [render setFrameDataFillback:^NSData *{
        return [wself audioRenderFillData];
    }];
    [render play];
    _renderId ++;
    [self renderVideo:_renderId];
}

- (void)_pause {
    AudioRender *render = [AudioRender sharedInstance];
    if (!render.playing) return;
    
    [render setFrameDataFillback:nil];
    [render pause];
}

-(void)setProgressCB:(void(^)(double progress))progressCB {
    _progressCB = progressCB;
}

-(void)setEndPlayCB:(void(^)(void))endPlayCB {
    _endPlayCB = endPlayCB;
}

-(void)setProgress:(double)progress {
    if (progress > 1) progress = 1;
    if (progress < 0) progress = 0;
    
    BOOL playing = [AudioRender sharedInstance].playing;
    [self _pause];
    double seconds = progress * _format.duration;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{//TODO: 命令操作 放入同步队列
        self->_currentAudioFrame = nil;
        [self->_formatDecoder seekPosition:seconds decodeMore:playing];
        VideoFrame *frame = [self getVideoFrame];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_renderView renderTexture:frame.data];
            if (playing) {
                [self _play];
            }
        });
    });
}


-(void)callbackProgress:(double)progress {
    if (_progressCB) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_progressCB(progress);
        });
    }
}

-(void)callbackEndPlay {
    if (_endPlayCB) {
//        dispatch_async(dispatch_get_main_queue(), ^{
            self->_endPlayCB();
//        });
    }
}

-(NSData *)audioRenderFillData {
    AudioFrame *frame = [self getAudioFrame];
    double progress;
    if (!frame) {
        progress = 0;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _pause];
            [self setProgress:0];
            [self callbackEndPlay];
        });
    }else {
        _currentAudioFrame = frame;
        progress = frame.position / _format.duration;
    }
    [self callbackProgress:progress];
    return frame.data;
}



-(void)renderVideo:(int)reanderId {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while ([AudioRender sharedInstance].playing && reanderId == self->_renderId) {
            @autoreleasepool {
                VideoFrame *frame = [self getVideoFrame];
                if (!frame) {
                    break;
                }
                //同步计算方式
                if (self->_currentAudioFrame && self->_currentAudioFrame.position > 0) {//需要同步
                    if (frame.position + frame.duration < self->_currentAudioFrame.position) {//画面落后
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self->_renderView renderTexture:frame.data];
                        });
                        continue;
                    }
                    double delay = frame.position - self->_currentAudioFrame.position - self->_currentAudioFrame.duration;
                    if (self->_currentAudioFrame && delay > 0) {//画面超前
                        [NSThread sleepForTimeInterval:MIN(delay, 0.1)];
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_renderView renderTexture:frame.data];
                });
                [NSThread sleepForTimeInterval:frame.duration];
            }
        }
    });
}


-(VideoFrame *)getVideoFrame {
    VideoFrame *frame = [_formatDecoder getVideoFrame];
    return frame;
}

-(AudioFrame *)getAudioFrame {
    AudioFrame *frame = [_formatDecoder getAudioFrame];
    return frame;
}

@end
