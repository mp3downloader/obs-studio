#import "audiodevice_mgr_osx_impl.h"

#include "obs-app.hpp"
#include "window-basic-main.hpp"

#import "BackgroundMusic/BGMAudioDeviceManager.h"
#import "authentication_mgr.h"
#import <AVFoundation/AVFoundation.h>



@interface AudioDeviceMgr()
{
    NSDate *_coreAudioKilledTime;
}
@property (readonly) BGMAudioDeviceManager* audioDeviceMgr;

- (void)onDeviceConnected:(NSNotification *)notification;
@end

@implementation AudioDeviceMgr

+ (AudioDeviceMgr *)sharedInstance
{
    static AudioDeviceMgr *instance = nil;
    if (!instance)
    {
        instance = [[AudioDeviceMgr alloc] init];
    }
    
    return instance;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _audioDeviceMgr = [BGMAudioDeviceManager new];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDeviceConnected:) name:AVCaptureDeviceWasConnectedNotification object:nil];
    }
    return self;
}

- (BOOL)isVirtualAudioDeviceInstalled
{
    //判断是否存在virtual audio device, virtual audio device 不存在，[BGMAudioDeviceManager new] 会返回NULL
    if (!_audioDeviceMgr)
    {
        return NO;
    }
    
    //version
    NSString *path = [self getAudioDriverPath];
    NSString *bundleInfoPath = [path stringByAppendingString:@"/Contents/info.plist"];
    NSString *version = [[NSDictionary dictionaryWithContentsOfFile:bundleInfoPath] objectForKey:@"CFBundleShortVersionString"];
    
    NSString *installedPath = @"/Library/Audio/Plug-Ins/HAL/BetterRecorder Audio Device.driver";
    NSBundle *installedBundle = [NSBundle bundleWithPath:installedPath];
    NSString *installedVersion = [[installedBundle infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    
    if ([version compare:installedVersion options:NSNumericSearch] == NSOrderedDescending)
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)installVirtualAudioDevice
{    
    NSString *strDriverPath = [self getAudioDriverPath];
    if(strDriverPath == nil || strDriverPath.length <= 0 || ![[NSFileManager defaultManager] fileExistsAtPath:strDriverPath])
    {
        return NO;
    }
    
    NSString *strDestPath = @"/Library/Audio/Plug-Ins/HAL";
    NSString *strCreatePathScript = nil;
    if(![[NSFileManager defaultManager] fileExistsAtPath:strDestPath])
    {
        strCreatePathScript = [NSString stringWithFormat:@"/bin/mkdir -m 777 %@", strDestPath];
    }
    
    NSString *strCopyDriverScript = [NSString stringWithFormat:@"/bin/cp -r '%@' %@", strDriverPath, strDestPath];
    
    //kill coreaudiod
    NSString *strKillCoreaudiodScript = @"";
    NSString *strCoreaudioPid = [NSString stringWithFormat:@"%d", [[AuthorizationUtil sharedInstance] getPidOfProcess:@"coreaudiod"]];
    if ([strCoreaudioPid intValue] <= 0)
    {
        strCoreaudioPid = [NSString stringWithFormat:@"%d", [[AuthorizationUtil sharedInstance] getCoreAudioPid]];
    }
    
    NSString *strSigal = @"3";
    if (@available(macOS 10.15, *))
    {
        //force terminate
        strSigal = @"9";
    }
    
    if ([strCoreaudioPid intValue] > 0)
    {
        strKillCoreaudiodScript = [NSString stringWithFormat:@"/bin/kill -%@ %@", strSigal, strCoreaudioPid];
    }

    
    NSMutableString *strAppleScript = [[NSMutableString alloc] initWithString:@"do shell script \""];
    
    if(strCreatePathScript.length > 0)
    {
        [strAppleScript appendFormat:@"%@ && ", strCreatePathScript];
    }
    
    [strAppleScript appendFormat:@"%@ && %@ \" with prompt \"%@ \" with administrator privileges", strCopyDriverScript, strKillCoreaudiodScript, @""];
        
    NSString *strErrorDescription = nil;
    AppleScriptExecuteStatus runAppleScriptResult = [[AuthorizationUtil sharedInstance] runAppleScript:strAppleScript errorDescription:&strErrorDescription];
    switch (runAppleScriptResult)
    {
        case AppleScriptExecuteStatusSuccess:
        {
            _coreAudioKilledTime = [[NSDate date] copy];
            return YES;
        }
            break;
        case AppleScriptExecuteStatusCancel:
        {
            return NO;
        }
            break;
        case AppleScriptExecuteStatusError:
        {
            return NO;
        }
            break;
    }
}

- (BOOL)selectVirtualAudioDevice
{
    
}

- (BOOL)selectRealAudioDevice
{
    
}


- (NSString*)getAudioDriverPath
{
    NSString* mainPath = [[NSBundle mainBundle] builtInPlugInsPath];
    NSString* outPath = [mainPath stringByAppendingString:@"/BetterRecorder Audio Device.driver"];
    
    return outPath;
}

- (void)onDeviceConnected:(NSNotification *)notification
{
    //NSLog(@"");
    OBSBasic *main = reinterpret_cast<OBSBasic *>(App()->GetMainWindow());
    main->InitRecordingUI();
}
@end
