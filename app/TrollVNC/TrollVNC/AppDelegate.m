//
//  AppDelegate.m
//  TrollVNC
//
//  Created by 82Flex on 9/1/25.
//

#import "AppDelegate.h"
#import "TVNCHotspotManager.h"
#import "TVNCServiceCoordinator.h"
#import <AVFoundation/AVFoundation.h>

@interface AppDelegate ()

@property (nonatomic, strong) AVAudioPlayer *silentPlayer;

- (void)startSilentAudio;
- (void)audioSessionInterrupted:(NSNotification *)note;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    [[TVNCServiceCoordinator sharedCoordinator] registerServiceMonitor];
    [[TVNCHotspotManager sharedManager] registerWithName:@"TrollVNC"];
    [self startSilentAudio];
    return YES;
}

#pragma mark - UISceneSession lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                                   options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}

- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after
    // application:didFinishLaunchingWithOptions. Use this method to release any resources that were specific to the
    // discarded scenes, as they will not return.
}

#pragma mark - 静音音频保活（TVNCGuard 补丁）

static NSData *TVNCBuildSilentWav(NSUInteger seconds, NSUInteger sampleRate) {
    uint32_t dataBytes = (uint32_t)(seconds * sampleRate * 2);
    NSMutableData *data = [NSMutableData dataWithCapacity:44 + dataBytes];

    uint32_t chunkSize = 36 + dataBytes;
    uint32_t fmtSize = 16;
    uint32_t rate = (uint32_t)sampleRate;
    uint32_t byteRate = rate * 2;
    uint16_t fmt = 1, channels = 1, blockAlign = 2, bits = 16;

    [data appendBytes:"RIFF" length:4];
    [data appendBytes:&chunkSize length:4];
    [data appendBytes:"WAVEfmt " length:8];
    [data appendBytes:&fmtSize length:4];
    [data appendBytes:&fmt length:2];
    [data appendBytes:&channels length:2];
    [data appendBytes:&rate length:4];
    [data appendBytes:&byteRate length:4];
    [data appendBytes:&blockAlign length:2];
    [data appendBytes:&bits length:2];
    [data appendBytes:"data" length:4];
    [data appendBytes:&dataBytes length:4];
    [data increaseLengthBy:dataBytes];
    return data;
}

- (void)startSilentAudio {
    NSError *err = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionMixWithOthers
                   error:&err];
    [session setActive:YES error:&err];

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tvnc-silence.wav"];
    [TVNCBuildSilentWav(1, 8000) writeToFile:path atomically:YES];

    self.silentPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                              error:&err];
    self.silentPlayer.numberOfLoops = -1;
    self.silentPlayer.volume = 0.0;
    [self.silentPlayer play];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioSessionInterrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];
    NSLog(@"[TrollVNC] 静音音频保活已启动");
}

- (void)audioSessionInterrupted:(NSNotification *)note {
    NSNumber *type = note.userInfo[AVAudioSessionInterruptionTypeKey];
    if (type.unsignedIntegerValue == AVAudioSessionInterruptionTypeEnded) {
        [[AVAudioSession sharedInstance] setActive:YES error:NULL];
        [self.silentPlayer play];
        NSLog(@"[TrollVNC] 音频中断结束，恢复静音播放");
    }
}

@end
