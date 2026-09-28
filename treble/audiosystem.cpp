// libmedia.so (vendor) — the nine android::AudioSystem statics that
// audio.primary.mt6737m.so (both ABIs) imports from the Nougat MTK libmedia.
//
// FACT (symbol audit of the HAL's closure against this tree, 2026-09-28):
// with libtinyxml and the other vendor libraries in place, the HAL's only
// unresolved imports are these nine plus the twelve tinycompress calls
// (tinycompress.cpp).  Eight are MediaTek "voice unlock" (wake-on-voice)
// entry points AOSP never had; the ninth, getDeviceConnectionState, is the
// Nougat two-argument form (Android 13 takes a device name as well).  The
// platform libmedia.so is system-only and would not give any of them.
//
// Same answers as LOS 16 on this device, where the HAL played sound through
// them (los16-ct07 device/meizu/m5c/shims/audio_voiceunlock.c): voice unlock
// is never enabled on this ROM, so every call reports "nothing"; the
// connection state is AUDIO_POLICY_DEVICE_STATE_UNAVAILABLE (0), so the HAL
// never believes a device the policy did not announce through set_parameters.
// Return types are not part of the mangled names; the declarations below
// reproduce the imports exactly (checked with llvm-nm against the blob).
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
