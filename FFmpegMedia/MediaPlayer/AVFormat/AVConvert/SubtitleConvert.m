//
//  SubtitleConvert.m
//  FFmpeg
//
//  Created by YLCHUN on 2018/11/5.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "SubtitleConvert.h"
#import "AVStreams.h"
#import "AVObj.h"
@implementation SubtitleConvert
{
    NSUInteger _assEvents;
}

+(instancetype)convertWithStream:(SubtitleStream *)stream {
    if (!stream.didOpen) return nil;
    return [[self alloc] initWithStream:stream];
}

-(instancetype)initWithStream:(SubtitleStream *)stream {
    if (self = [super init]) {
        _assEvents = getSubtitleASSEvents(stream);
    }
    return self;
}

+ (instancetype)convertWithCodecCtx:(AVCodecCtx *)codecCtx {
    if (!codecCtx) return nil;
    SubtitleConvert *convert = [self new];
    if (codecCtx.context->subtitle_header_size) {
        NSString *s = [[NSString alloc] initWithBytes:codecCtx.context->subtitle_header
                                               length:codecCtx.context->subtitle_header_size
                                             encoding:NSASCIIStringEncoding];
        if (s.length) {
            
            NSArray *fields = assParseEvents(s);
            if (fields.count && [fields.lastObject isEqualToString:@"Text"]) {
                convert->_assEvents = fields.count;
                NSLog(@"subtitle ass events: %@", [fields componentsJoinedByString:@","]);
            }
        }
    }
    return convert;
}

-(void)receive:(void(^)(NSString *data, double duration, double position))receiveCB atAVObj:(AVFrameObjBase *)avObj {
    if (!receiveCB || !avObj || ![avObj isKindOfClass:[AVSubtitleObj class]]) return;
    
    AVSubtitleObj *subtitle = (AVSubtitleObj *)avObj;
    if (!subtitle.data) return;
    
    NSMutableString *mStr = [NSMutableString string];
    
    for (NSUInteger i = 0; i < subtitle.data->num_rects; ++i) {
        
        AVSubtitleRect *rect = subtitle.data->rects[i];
        if (rect) {
            
            if (rect->text) { // rect->type == SUBTITLE_TEXT
                
                NSString *s = [NSString stringWithUTF8String:rect->text];
                if (s.length) [mStr appendString:s];
                
            } else if (rect->ass && _assEvents != -1) {
                
                NSString *s = [NSString stringWithUTF8String:rect->ass];
                if (s.length) {
                    NSArray *fields = assParseDialogue(s, _assEvents);
                    if (fields.count && [fields.lastObject length]) {
                        s = assRemoveCommandsFromEventText(fields.lastObject);
                        if (s.length) [mStr appendString:s];
                    }
                }
            }
        }
    }
    
    if (mStr.length == 0) return;
    
    double position = subtitle.data->pts / AV_TIME_BASE + subtitle.data->start_display_time;
    double duration = (double)(subtitle.data->end_display_time - subtitle.data->start_display_time) / 1000.f;
    
    receiveCB([mStr copy], position, duration);
    
}

static NSArray *assParseEvents (NSString *events)
{
    NSRange r = [events rangeOfString:@"[Events]"];
    if (r.location != NSNotFound) {
        
        NSUInteger pos = r.location + r.length;
        
        r = [events rangeOfString:@"Format:"
                          options:0
                            range:NSMakeRange(pos, events.length - pos)];
        
        if (r.location != NSNotFound) {
            
            pos = r.location + r.length;
            r = [events rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]
                                        options:0
                                          range:NSMakeRange(pos, events.length - pos)];
            
            if (r.location != NSNotFound) {
                
                NSString *format = [events substringWithRange:NSMakeRange(pos, r.location - pos)];
                NSArray *fields = [format componentsSeparatedByString:@","];
                if (fields.count > 0) {
                    
                    NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
                    NSMutableArray *ma = [NSMutableArray array];
                    for (NSString *s in fields) {
                        [ma addObject:[s stringByTrimmingCharactersInSet:ws]];
                    }
                    return ma;
                }
            }
        }
    }
    
    return nil;
}

static NSArray *assParseDialogue(NSString *dialogue, NSUInteger numFields) {
    if ([dialogue hasPrefix:@"Dialogue:"]) {
        
        NSMutableArray *ma = [NSMutableArray array];
        
        NSRange r = {@"Dialogue:".length, 0};
        NSUInteger n = 0;
        
        while (r.location != NSNotFound && n++ < numFields) {
            
            const NSUInteger pos = r.location + r.length;
            
            r = [dialogue rangeOfString:@","
                                options:0
                                  range:NSMakeRange(pos, dialogue.length - pos)];
            
            const NSUInteger len = r.location == NSNotFound ? dialogue.length - pos : r.location - pos;
            NSString *p = [dialogue substringWithRange:NSMakeRange(pos, len)];
            p = [p stringByReplacingOccurrencesOfString:@"\\N" withString:@"\n"];
            [ma addObject: p];
        }
        
        return ma;
    }
    
    return nil;
}

static NSString *assRemoveCommandsFromEventText(NSString *text)
{
    NSMutableString *ms = [NSMutableString string];
    
    NSScanner *scanner = [NSScanner scannerWithString:text];
    while (!scanner.isAtEnd) {
        
        NSString *s;
        if ([scanner scanUpToString:@"{\\" intoString:&s]) {
            
            [ms appendString:s];
        }
        
        if (!([scanner scanString:@"{\\" intoString:nil] &&
              [scanner scanUpToString:@"}" intoString:nil] &&
              [scanner scanString:@"}" intoString:nil])) {
            
            break;
        }
    }
    
    return ms;
}

static NSUInteger getSubtitleASSEvents(SubtitleStream *stream) {
    if (stream.codecCtx.context->subtitle_header_size) {
        NSString *s = [[NSString alloc] initWithBytes:stream.codecCtx.context->subtitle_header
                                               length:stream.codecCtx.context->subtitle_header_size
                                             encoding:NSASCIIStringEncoding];
        if (s.length) {
            
            NSArray *fields = assParseEvents(s);
            if (fields.count && [fields.lastObject isEqualToString:@"Text"]) {
                return fields.count;
            }
        }
    }
    return 0;
}
@end
