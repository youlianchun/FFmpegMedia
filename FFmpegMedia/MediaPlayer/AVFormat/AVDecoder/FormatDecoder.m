//
//  FormatDecoder.m
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/12/14.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "FormatDecoder.h"
#import "AVObj.h"
#import "AVStreams.h"
#import "AVFrames.h"
#import "PacketReader.h"
#import "PacketDecoder.h"
#import "AudioConvert.h"
#import "VideoConvert.h"
#import "SubtitleConvert.h"

@interface FormatDecoder()<PacketReaderDelegate>
@end
@implementation FormatDecoder
{
    AudioStream *_audioStream;
    VideoStream *_videoStream;
//    SubtitleStream *_subtitleStream;
    
    PacketDecoder *_audioDecoder;
    VideoPacketDecoder *_videoDecoder;
//    PacketDecoder *_sutitleDecoder;
    
    PacketReader *_packetReader;
    BOOL _didOpen;
}


-(instancetype)initWithVideoFormat:(AVFormatObj*)format {
    self = [super init];
    if (self) {
        _audioStream = [[AudioStream alloc] initWithFormat:format];
        _videoStream = [[VideoStream alloc] initWithFormat:format];
//      _subtitleStream = [[SubtitleStream alloc] initWithFormat:format];
        
        _packetReader = [[PacketReader alloc] initWithFormat:format delegate:self];
    }
    return self;
}

-(double)videoWidth {
    if (!_didOpen) return 0;
    return _videoDecoder.width;
}
-(double)videoHeight {
    if (!_didOpen) return 0;
    return _videoDecoder.height;
}

-(VideoTextureType)videoTextureType {
    if (!_didOpen) return VideoTextureType_rgb;
    return _videoDecoder.type;
}

-(void)didDeceive:(AVPacketObj *)packet atReader:(PacketReader*)reader {
    if (!packet) { //end playing
        [_audioDecoder sendPacket:packet];
        [_videoDecoder sendPacket:packet];
//        [_sutitleDecoder sendPacket:packet];
        return;
    }
    PacketDecoder *packetDecoder;
    switch (packet.type) {
        case AVPacketType_audio:
//            return;
            packetDecoder = _audioDecoder;
            break;
        case AVPacketType_video:
            packetDecoder = _videoDecoder;
            break;
        case AVPacketType_suntitle:
//            packetDecoder = _sutitleDecoder;
            break;
        default:
            break;
    }
//    NSLog(@"type.. %@", packet.typeStr);
    [packetDecoder sendPacket:packet];
}

-(void)open {
    if (_didOpen) return;
    _didOpen = YES;
    [_audioStream openCodec];
    [_videoStream openCodec];
//    [_subtitleStream openCodec];
    
    _audioDecoder = [[PacketDecoder alloc] initWithCodecCtx:_audioStream.codecCtx convertCls:[AudioConvert class] frameCls:[AudioFrame class]];
    _videoDecoder = [[VideoPacketDecoder alloc] initWithCodecCtx:_videoStream.codecCtx convertCls:[VideoConvert class] frameCls:[VideoFrame class]];
//    _sutitleDecoder = [[PacketDecoder alloc] initWithCodecCtx:_subtitleStream.codecCtx convertCls:[SubtitleConvert class]];

    [_videoDecoder start];
    [_audioDecoder start];
//    [_sutitleDecoder start];
    
}

-(void)close {
    if (!_didOpen) return;
    _didOpen = NO;
    [_audioDecoder stop];
    [_videoDecoder stop];
//    [_sutitleDecoder stop];
}

-(void)startPacketReader {
    [_packetReader start];
}

-(void)stopPacketReader {
    [_packetReader stop];
}

-(void)seekPosition:(double)seconds decodeMore:(BOOL)decodeMore {
    if (!_didOpen) return;
    [self stopPacketReader];
    [self clean];
    [self setDecoderIsPreview:!decodeMore];
    [self setStreamPosition:seconds];
    [self startPacketReader];
}

-(void)decodeMore {
    [self setDecoderIsPreview:NO];
}

-(void)setStreamPosition:(double)seconds {
    [_audioStream setPosition:seconds];
    [_videoStream setPosition:seconds];
//    [_subtitleStream setPosition:seconds];
}

-(void)clean {
    [_audioDecoder clean];
    [_videoDecoder clean];
//    [_sutitleDecoder clean];
}

-(void)setDecoderIsPreview:(BOOL)isPreview {
    [_audioDecoder setIsPreview:NO];
    [_videoDecoder setIsPreview:NO];
//    [_sutitleDecoder setIsPreview:NO];
}

-(AudioFrame *)getAudioFrame {
    if (!_didOpen) return nil;
    [self waitIfNeed];
    return (AudioFrame *)[_audioDecoder getFrame];
}

-(VideoFrame *)getVideoFrame {
    if (!_didOpen) return nil;
    [self waitIfNeed];
    return (VideoFrame *)[_videoDecoder getFrame];
}

-(SubtitleFrame *)getSutitleFrame {
    if (!_didOpen) return nil;
    return nil;
//    return (SubtitleFrame *)[_sutitleDecoder getFrame];
}
-(void)waitIfNeed {
//    while (true) {
//        if (_audioDecoder.frameCount < 5 || _videoDecoder.frameCount < 5) {
//            [NSThread sleepForTimeInterval:0.1];
//        }else {
//            break;
//        }
//    }
}
@end
