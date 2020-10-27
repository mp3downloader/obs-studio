#import "audiodevice_mgr_osx_impl.h"

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

- (BOOL)isVirtualAudioDeviceInstalled
{
    //文件是否存在
    
    //判断是否存在virtual audio device
}

- (BOOL)installVirtualAudioDevice
{
    
}

- (BOOL)selectVirtualAudioDevice
{
    
}

- (BOOL)selectRealAudioDevice
{
    
}

@end
