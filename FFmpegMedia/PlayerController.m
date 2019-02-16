//
//  PlayerController.m
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/11/29.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "PlayerController.h"
#import "MediaPlayer.h"

@interface PlayerController ()
{
    MediaPlayer *_player;
    __weak IBOutlet UISlider *_timeSlider;
    __weak IBOutlet UIButton *_playBtn;
    __weak IBOutlet UILabel *_currentTimeLabel;
    __weak IBOutlet UILabel *_remainingTimeLabel;
}
@end

@implementation PlayerController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self mediaPlayerTest:[self localPath]];
}

-(void)mediaPlayerTest:(NSString *)path {
    [self changePlayState:NO];
    
    _player = [[MediaPlayer alloc] initWithPath:path];
    __weak typeof(self) wself = self;
    
    [_player setProgressCB:^(double progress) {
        [wself changePlayProgress:progress];
    }];
    [_player setEndPlayCB:^{
        [wself changePlayState:NO];
    }];
    
    [_player prepare];
    
    [self layoutPlayerView:_player.view];
}

-(void)layoutPlayerView:(UIView *)view {
    [self.view insertSubview:view atIndex:0];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [view.superview addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:view.superview attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
    [view.superview addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:view.superview attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
    [view.superview addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:view.superview attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [view.superview addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
}

- (IBAction)playBtnAction:(UIButton *)sender {
    if (sender.tag == 0) {
        [self changePlayState:YES];
        [_player play];
    }else {
        [self changePlayState:NO];
        [_player pause];
    }
}

- (IBAction)timeSliderChangedAction:(UISlider *)sender {
    [self->_player setProgress:sender.value];
    [self changePlayProgress:sender.value];
}

-(void)changePlayState:(BOOL)isPlaying {
    if (isPlaying) {
        _playBtn.tag = 1;
        [_playBtn setTitle:@"暂停" forState:UIControlStateNormal];
    }else {
        _playBtn.tag = 0;
        [_playBtn setTitle:@"播放" forState:UIControlStateNormal];
    }
}

-(void)changePlayProgress:(double)progress {
    if (_timeSlider.state == UIControlStateNormal) {
        _timeSlider.value = progress;
    }
    int currentTime = _player.duration * progress;
    int remainingTime = _player.duration - currentTime;
    _currentTimeLabel.text = toMMSS(currentTime);
    _remainingTimeLabel.text = toMMSS(remainingTime);
}

static NSString *toMMSS(int seconds) {
    return [NSString stringWithFormat:@"%02d:%02d", seconds/60, seconds%60];
}

- (NSString *)localPath {
    return [[NSBundle mainBundle] pathForResource:@"bigbuckbunyn" ofType:@"mp4"];
}


@end
