//audiodevice_mgr listen input stream, play audio on real device
//when virtual device was selected, when headphone plug in or out, change play device automatically


bool IsAudioDriverInstalled();
bool InstallAudioDriver();
bool SelectVirtualAudioDevice();
bool UnselectVirtualAudioDevice();

