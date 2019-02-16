//
//  AudioRender.m
//  FFmpegTest
//
//  Created by YLCHUN on 2018/10/31.
//  Copyright © 2018年 times. All rights reserved.
//

#import "AudioRender.h"
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVFoundation.h>

static const int SAMPLING_RATE = 44100;
static const int MAX_FRAME_SIZE = 4096;
static const int MAX_CHAN = 2;
static const int MAX_SAMPLE_DUMPED = 5;

//static const double IO_BUFFER_DURATION = 0.0232; // 一包的时长(s) -> 采样率44100、1024个采样点 -> 1024.0/44100.0

@implementation AudioRender
{
    BOOL _activated;
    float *_outData;
    
    AudioUnit _audioUnit;
    AudioRenderFillDataCallback _fillDataCallback;
    
    UInt32 _numBytesPerSample;
}

@synthesize channels = _channels;
@synthesize samplingRate = _samplingRate;
@synthesize playing = _playing;

static BOOL CheckStatusErr(OSStatus status, const char *messgae)
{
    if (status == noErr)  return NO;
    
    char fourCC[16];
    *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
    fourCC[4] = '\0';
    if (isprint(fourCC[0] && isprint(fourCC[1]) && isprint(fourCC[2]) && isprint(fourCC[3]))) {
        NSLog(@"%s: %s", messgae, fourCC);
    }else {
        NSLog(@"%s: %d", messgae, status);
    }
    //        if (fatal) exit(-1);
    return YES;
}

static OSStatus renderCallback (void                        *inRefCon,
                                AudioUnitRenderActionFlags  *ioActionFlags,
                                const AudioTimeStamp        *inTimeStamp,
                                UInt32                      inOutputBusNumber,
                                UInt32                      inNumberFrames,
                                AudioBufferList             *ioData)
{
    AudioRender *self = (__bridge AudioRender *)inRefCon;
    return [self renderFrames:inNumberFrames ioData:ioData];
}

+(instancetype)sharedInstance {
    static id share = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        share = [[self alloc] init];
    });
    return share;
}

- (id)init
{
    self = [super init];
    if (self) {
        _outData = (float *)calloc(MAX_FRAME_SIZE*MAX_CHAN, sizeof(float));
    }
    return self;
}

- (void)dealloc
{
    if (_outData) {
        free(_outData);
        _outData = NULL;
    }
}

-(void)setFillDataCallback:(AudioRenderFillDataCallback)fillDataCallback {
    _fillDataCallback = fillDataCallback;
}

- (void)setFrameDataFillback:(NSData*(^)(void))fillback {
    if (!fillback) return;
    
    __block NSData *data = nil;
    __block NSUInteger pos = 0;
    __block NSUInteger fdLen = 0;
    [self setFillDataCallback:^(float *fillData, UInt32 numFrames, UInt32 numChannels) {
        if (!data) {
            fdLen = numFrames * (numChannels * sizeof(float));
            data = fillback();
            pos = 0;
        }
        if (data) {
            const void *bytes = (Byte *)data.bytes + pos;
            NSUInteger len = MIN(data.length - pos, fdLen);
            memcpy(fillData, bytes, len);
            pos += len;
            if (pos >= data.length-1) {
                data = nil;
            }
        }else {
             memset(fillData, 0, fdLen);
            //error
        }
    }];
}
#pragma mark - private

// Debug: dump the current frame data. Limited to 20 samples.

static void dumpAudioSamples(NSString *prefix, SInt16 *dataBuffer, NSString *samplePrintFormat, int sampleCount, int channelCount)
{
    NSMutableString *dump = [NSMutableString stringWithFormat:@"%@", prefix];
    for (int i = 0; i < MIN(MAX_SAMPLE_DUMPED, sampleCount); i++)
    {
        for (int j = 0; j < channelCount; j++)
        {
            [dump appendFormat:samplePrintFormat, dataBuffer[j + i * channelCount]];
        }
        [dump appendFormat:@"\n"];
    }
    NSLog(@"%@", dump);
}


- (BOOL) setupAudio
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:NULL];
    
    _samplingRate = SAMPLING_RATE;//audioSession.sampleRate;
    
    // Describe the output unit.
    
    // AudioComponentDescription 是用于描述音频组件的唯一标识和标识的结构。
    AudioComponentDescription description = {0};
    description.componentType = kAudioUnitType_Output;// 一个音频组件的通用的独特的四字节码标识
    description.componentSubType = kAudioUnitSubType_RemoteIO;// 根据componentType设置相应的类型
    description.componentManufacturer = kAudioUnitManufacturer_Apple;// 厂商的身份验证
    description.componentFlags = 0;
    description.componentFlagsMask = 0;
    /*
     AudioUnit.framework这个库提供DSP数字信号处理相关的插件，包括编解码，混音，音频均衡等。
     */
    // Get component
    AudioComponent component = AudioComponentFindNext(NULL, &description);
    OSStatus status = noErr;
    status = AudioComponentInstanceNew(component, &_audioUnit);
    if (CheckStatusErr(status, "Couldn't create the output audio unit")) return NO;
    
    UInt32 size;
    
    // 重新设置采样率
    // Check the output stream format
    AudioStreamBasicDescription outputFormat;
    size = sizeof(outputFormat);
    status = AudioUnitGetProperty(_audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &outputFormat,
                                  &size);
    if (CheckStatusErr(status, "Couldn't get the hardware output stream format")) return NO;

    outputFormat.mSampleRate = _samplingRate;
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &outputFormat,
                                  size);
    if (CheckStatusErr(status, "Couldn't set the hardware output stream format")) {
        // just warning
    }
    
    _numBytesPerSample = outputFormat.mBitsPerChannel / 8;
    _channels = outputFormat.mChannelsPerFrame;
    
    // Slap a render callback on the unit
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = renderCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  0,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    if (CheckStatusErr(status, "Couldn't set the render callback on the audio unit")) return NO;
    
    status = AudioUnitInitialize(_audioUnit);
    if (CheckStatusErr(status, "Couldn't initialize the audio unit")) return NO;
    
    return YES;
}


- (BOOL) renderFrames: (UInt32) numFrames
               ioData: (AudioBufferList *) ioData
{
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    
    if (_playing && _fillDataCallback ) {
        
        // Collect data to render from the callbacks
        
        _fillDataCallback(_outData, numFrames, _channels);

        // Put the rendered data into the output buffer
        if (_numBytesPerSample == 4) // then we've already got floats
        {
            float zero = 0.0;
            
            for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
                
                int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
                
                for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                    //矢量标量添加; 单精度
                    vDSP_vsadd(_outData+iChannel, _channels, &zero, (float *)ioData->mBuffers[iBuffer].mData, thisNumChannels, numFrames);
                }
            }
        }
        else if (_numBytesPerSample == 2) // then we need to convert SInt16 -> Float (and also scale)
        {
            //            dumpAudioSamples(@"Audio frames decoded by FFmpeg:\n",
            //                             _outData, @"% 12.4f ", numFrames, _numOutputChannels);
            
            float scale = (float)INT16_MAX;
            //单精度实矢量标量乘法。
            vDSP_vsmul(_outData, 1, &scale, _outData, 1, numFrames*_channels);
            
#ifdef DUMP_AUDIO_DATA
            NSLock(@"Buffer %u - Output Channels %u - Samples %u",
                        (uint)ioData->mNumberBuffers, (uint)ioData->mBuffers[0].mNumberChannels, (uint)numFrames);
#endif
            
            for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
                
                int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
                
                for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                    //将单精度浮点值数组转换为带符号的16位整数值，舍入为零。
                    vDSP_vfix16(_outData+iChannel, _channels, (SInt16 *)ioData->mBuffers[iBuffer].mData+iChannel, thisNumChannels, numFrames);
                }
#ifdef DUMP_AUDIO_DATA
                dumpAudioSamples(@"Audio frames decoded by FFmpeg and reformatted:\n",
                                 ((SInt16 *)ioData->mBuffers[iBuffer].mData),
                                 @"% 8d ", numFrames, thisNumChannels);
#endif
            }
            
        }
    }
    
    return noErr;
}

#pragma mark - public

- (BOOL) activate
{
    if (!_activated) {
        if ([self setupAudio]) {
            _activated = YES;
        }
    }
    
    return _activated;
}

- (void) deactivate
{
    if (_activated) {
        [self pause];
        OSStatus status = noErr;
        status = AudioUnitUninitialize(_audioUnit);
        CheckStatusErr(status, "Couldn't uninitialize the audio unit");
        
        status = AudioComponentInstanceDispose(_audioUnit);
        CheckStatusErr(status, "Couldn't dispose the output audio unit");
        
        _activated = NO;
    }
}

- (void) pause
{
    if (_playing) {
        OSStatus status = AudioOutputUnitStop(_audioUnit);
        _playing = status == noErr ? NO : YES;
        CheckStatusErr(status, "Couldn't stop the output unit");
    }
}

- (BOOL) play
{
    if (!_playing) {
        if ([self activate]) {
            OSStatus status = AudioOutputUnitStart(_audioUnit);
            CheckStatusErr(status, "Couldn't start the output unit");
            _playing = status == noErr ? YES : NO;
        }
    }
    return _playing;
}

@end

