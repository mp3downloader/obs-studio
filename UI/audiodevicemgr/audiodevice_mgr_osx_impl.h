#import <Cocoa/Cocoa.h>

@interface AudioDeviceMgr : NSObject
{
    //real output audio device
    
}
+ (AudioDeviceMgr *)sharedInstance;

- (BOOL)isVirtualAudioDeviceInstalled;
- (BOOL)installVirtualAudioDevice;
- (BOOL)selectVirtualAudioDevice;
- (BOOL)selectRealAudioDevice;
@end
