#import "MediaBridge.h"
#import <ffmpegkit/FFmpegKit.h>
#import <ffmpegkit/FFprobeKit.h>
#import <ffmpegkit/FFmpegKitConfig.h>
#import <ffmpegkit/ReturnCode.h>
#import <ffmpegkit/Statistics.h>
#import <ffmpegkit/Log.h>

@implementation UCFFmpegRunner {
    BOOL _cancelled;
    long _sessionID;
}
- (instancetype)init {
    if ((self = [super init])) {
        _sessionID = -1;
        [FFmpegKitConfig setSessionHistorySize:8];
    }
    return self;
}
- (void)registerSession:(long)sessionID {
    @synchronized (self) {
        _sessionID = sessionID;
        if (_cancelled) [FFmpegKit cancel:sessionID];
    }
}
- (BOOL)isCancelled {
    @synchronized (self) { return _cancelled; }
}
- (void)finishSession:(long)sessionID {
    @synchronized (self) { if (_sessionID == sessionID) _sessionID = -1; }
}
- (void)cancel {
    @synchronized (self) {
        _cancelled = YES;
        if (_sessionID >= 0) [FFmpegKit cancel:_sessionID];
    }
}
- (void)runFFmpeg:(NSArray<NSString *> *)arguments progress:(void (^)(double, double))progress completion:(void (^)(int, NSString *))completion {
    if ([self isCancelled]) { completion(255, @""); return; }
    FFmpegSession *session = [FFmpegKit executeWithArgumentsAsync:arguments
        withCompleteCallback:^(FFmpegSession *finished) {
            [self finishSession:[finished getSessionId]];
            ReturnCode *code = [finished getReturnCode];
            NSString *text = [finished getOutput] ?: @"";
            // Keep diagnostics bounded, and never keep every completed media session in memory.
            if (text.length > 16384) text = [text substringFromIndex:text.length - 16384];
            completion(code ? [code getValue] : -1, text);
        } withLogCallback:^(Log *log) { /* session-owned logging only */ }
        withStatisticsCallback:^(Statistics *statistics) {
            progress([statistics getTime] / 1000.0, [statistics getSpeed]);
        }];
    [self registerSession:[session getSessionId]];
}
- (void)runFFprobe:(NSArray<NSString *> *)arguments completion:(void (^)(int, NSString *))completion {
    if ([self isCancelled]) { completion(255, @""); return; }
    FFprobeSession *session = [FFprobeKit executeWithArgumentsAsync:arguments
        withCompleteCallback:^(FFprobeSession *finished) {
            [self finishSession:[finished getSessionId]];
            ReturnCode *code = [finished getReturnCode];
            completion(code ? [code getValue] : -1, [finished getOutput] ?: @"");
        } withLogCallback:^(Log *log) { }];
    [self registerSession:[session getSessionId]];
}
@end
