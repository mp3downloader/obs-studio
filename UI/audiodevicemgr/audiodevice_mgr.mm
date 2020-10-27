#import "audiodevice_mgr_osx_impl.h"

bool isAudioDriverInstalled()
{
	return [[AudioDeviceMgr sharedInstance] isVirtualAudioDeviceInstalled];
}

bool installAudioDriver()
{
	return [[AudioDeviceMgr sharedInstance] installVirtualAudioDevice];
}

bool selectVirtualAudioDevice()
{
	return [[AudioDeviceMgr sharedInstance] selectVirtualAudioDevice];
}

bool unselectVirtualAudioDevice()
{
	return [[AudioDeviceMgr sharedInstance] selectRealAudioDevice];	
}
