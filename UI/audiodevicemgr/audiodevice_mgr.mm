#import "audiodevice_mgr_osx_impl.h"

bool IsAudioDriverInstalled()
{
	return [[AudioDeviceMgr sharedInstance] isVirtualAudioDeviceInstalled];
}

bool InstallAudioDriver()
{
	return [[AudioDeviceMgr sharedInstance] installVirtualAudioDevice];
}

bool SelectVirtualAudioDevice()
{
	return [[AudioDeviceMgr sharedInstance] selectVirtualAudioDevice];
}

bool UnselectVirtualAudioDevice()
{
	return [[AudioDeviceMgr sharedInstance] selectRealAudioDevice];	
}
