#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

/// One sequential, cancellable chain of native media sessions. Never run commands in a shell.
@interface UCFFmpegRunner : NSObject
- (void)runFFmpeg:(NSArray<NSString *> *)arguments
         progress:(void (^)(double seconds, double speed))progress
       completion:(void (^)(int code, NSString *output))completion
    NS_SWIFT_NAME(ffmpeg(_:progress:completion:));
- (void)runFFprobe:(NSArray<NSString *> *)arguments
        completion:(void (^)(int code, NSString *output))completion
    NS_SWIFT_NAME(ffprobe(_:completion:));
- (void)cancel;
@end
NS_ASSUME_NONNULL_END
