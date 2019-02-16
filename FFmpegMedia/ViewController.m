//
//  ViewController.m
//  FFmpeg
//
//  Created by YLCHUN on 2018/11/1.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "ViewController.h"
#import "PCQueue.h"
#import "PlayerController.h"

@interface ViewController ()

@end

@implementation ViewController
{
    PCQueue *_dataSource;
    PCQueue *_queue;
    BOOL _produceing;
    BOOL _consumeing;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)xCodecAction:(UIButton *)sender {
    kDisableVTDecode = YES;
    [self pushPlayer];
}

- (IBAction)hCodecAction:(UIButton *)sender {
    kDisableVTDecode = NO;
    [self pushPlayer];
}

-(void)pushPlayer {
    PlayerController *vc = [PlayerController new];
    [self.navigationController pushViewController:vc animated:YES];
}


-(void)pctest {
    _dataSource = [PCQueue queueWithSize:1000];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        long i = 0;
        while (true) {
            [self->_dataSource push:@(i++)];
        }
    });
    
    _queue = [PCQueue queueWithSize:10];
    
    for (int i = 0; i < 1; i++) {
        NSThread *thread1 = [[NSThread alloc] initWithTarget:self selector:@selector(onProduce) object:nil];
        thread1.name = [NSString stringWithFormat:@"%d", i];
        [thread1 start];
    }
    for (int i = 0; i < 2; i++) {
        NSThread *thread2 = [[NSThread alloc] initWithTarget:self selector:@selector(onConsume) object:nil];
        thread2.name = [NSString stringWithFormat:@"%d", i];
        [thread2 start];
    }
}

- (void)onProduce {
    while (TRUE) {
        if (!_produceing) {
            [NSThread sleepForTimeInterval:.2];
            continue;
        }
        id obj = [_dataSource pop];
        [_queue push:obj];
        NSLog(@"+++ v:%ld, t:%@",  [obj integerValue],  [NSThread currentThread].name);
    }
}

- (void)onConsume {
    while (TRUE) {
        if (!_consumeing) {
            [NSThread sleepForTimeInterval:.2];
            continue;
        }
        double t = (arc4random() % 101) / 1000.0;
        [NSThread sleepForTimeInterval:t];
        id obj = [_queue pop];
        NSLog(@"--- v:%ld, t:%@",  [obj integerValue], [NSThread currentThread].name);
        if ([obj integerValue] == -1) {
            NSLog(@"error \n\n\n");
        }
    }
}

- (IBAction)pcBeginAction:(UIButton *)sender {
    sender.hidden = YES;
    [self pctest];
}

- (IBAction)cleanAction:(UIButton *)sender {
    NSLog(@" clena begin===\n\n");
    [_queue clean];
    NSLog(@"\n\n clena end===");
}

- (IBAction)produceAction:(UIButton *)sender {
    if (sender.tag == 0) {
        [sender setTitle:@"停止生产" forState:UIControlStateNormal];
        _produceing = true;
        sender.tag = 1;
    }else {
        [sender setTitle:@"开始生产" forState:UIControlStateNormal];
        _produceing = false;
        sender.tag = 0;
    }
}

- (IBAction)consumeAction:(UIButton *)sender {
    if (sender.tag == 0) {
        [sender setTitle:@"停止消费" forState:UIControlStateNormal];
        _consumeing = true;
        sender.tag = 1;
    }else {
        [sender setTitle:@"开始消费" forState:UIControlStateNormal];
        _consumeing = false;
        sender.tag = 0;
    }
}

@end
