// libmedia.so (vendor): the nine android::AudioSystem statics that
// audio.primary.mt6737m imports from the Nougat MTK libmedia.
//
// Eight are MediaTek voice unlock entry points, which are never enabled and
// report nothing. getDeviceConnectionState is the Nougat two-argument form and
// reports AUDIO_POLICY_DEVICE_STATE_UNAVAILABLE.
#include <stdint.h>

namespace android {

class AudioSystem {
  public:
    static int ReadRefFromRing(void*, uint32_t, void*);
    static int SetVoiceUnlockSRC(uint32_t, uint32_t);
    static bool startVoiceUnlockDL();
    static bool stopVoiceUnlockDL();
    static int GetVoiceUnlockULTime(void*);
    static int GetVoiceUnlockDLLatency();
    static bool getVoiceUnlockDLInstance();
    static void freeVoiceUnlockDLInstance();
    static int getDeviceConnectionState(uint32_t, const char*);
};

int AudioSystem::ReadRefFromRing(void*, uint32_t, void*) { return 0; }
int AudioSystem::SetVoiceUnlockSRC(uint32_t, uint32_t) { return 0; }
bool AudioSystem::startVoiceUnlockDL() { return false; }
bool AudioSystem::stopVoiceUnlockDL() { return false; }
int AudioSystem::GetVoiceUnlockULTime(void*) { return 0; }
int AudioSystem::GetVoiceUnlockDLLatency() { return 0; }
bool AudioSystem::getVoiceUnlockDLInstance() { return false; }
void AudioSystem::freeVoiceUnlockDLInstance() {}
int AudioSystem::getDeviceConnectionState(uint32_t, const char*) { return 0; }

}  // namespace android
