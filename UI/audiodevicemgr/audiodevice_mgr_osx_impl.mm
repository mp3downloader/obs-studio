#import "audiodevice_mgr_osx_impl.h"
#import "BackgroundMusic/BGMAudioDeviceManager.h"

@interface AudioDeviceMgr()
@property (readonly) BGMAudioDeviceManager* audioDeviceMgr;
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
    }
    return self;
}

- (BOOL)isVirtualAudioDeviceInstalled
{
    //文件是否存在
    
    //判断是否存在virtual audio device
    if (!_audioDeviceMgr)
    {
        return NO;
    }
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
