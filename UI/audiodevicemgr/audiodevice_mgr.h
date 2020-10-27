//audiodevice_mgr listen input stream, play audio on real device
//when virtual device was selected, when headphone plug in or out, change play device automatically


bool isAudioDriverInstalled();
bool installAudioDriver();
bool selectVirtualAudioDevice();
bool unselectVirtualAudioDevice();

