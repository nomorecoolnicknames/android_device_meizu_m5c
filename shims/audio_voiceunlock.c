/*
 * No-op stubs for the MediaTek voice-unlock AudioSystem symbols imported by
 * audio.primary.mt6737m.so. AOSP libmedia does not export them, so the HAL
 * fails to load without this shim (see TARGET_LD_SHIM_LIBS). Nothing calls
 * the voice-unlock feature, so every stub returns 0 / NULL.
 *
 * Return types are not part of the mangled names, so the asm labels below
 * match the blob's imports; the pointer-returning one returns a clean NULL.
 */

#include <stddef.h>
#include <stdint.h>

#define VU_STUB(ret, name, mangled, params, retval) \
    ret name params __asm__(mangled);               \
    ret name params { return retval; }

/* int AudioSystem::ReadRefFromRing(void*, uint32_t, void*) */
VU_STUB(int, m5c_vu_ReadRefFromRing,
        "_ZN7android11AudioSystem15ReadRefFromRingEPvjS1_",
        (void *a __attribute__((unused)), uint32_t b __attribute__((unused)),
         void *c __attribute__((unused))), 0)

/* int AudioSystem::SetVoiceUnlockSRC(uint32_t, uint32_t) */
VU_STUB(int, m5c_vu_SetVoiceUnlockSRC,
        "_ZN7android11AudioSystem17SetVoiceUnlockSRCEjj",
        (uint32_t a __attribute__((unused)), uint32_t b __attribute__((unused))), 0)

/* bool AudioSystem::stopVoiceUnlockDL() */
VU_STUB(int, m5c_vu_stopVoiceUnlockDL,
        "_ZN7android11AudioSystem17stopVoiceUnlockDLEv", (void), 0)

/* bool AudioSystem::startVoiceUnlockDL() */
VU_STUB(int, m5c_vu_startVoiceUnlockDL,
        "_ZN7android11AudioSystem18startVoiceUnlockDLEv", (void), 0)

/* bool AudioSystem::GetVoiceUnlockULTime(void*) */
VU_STUB(int, m5c_vu_GetVoiceUnlockULTime,
        "_ZN7android11AudioSystem20GetVoiceUnlockULTimeEPv",
        (void *a __attribute__((unused))), 0)

/* int AudioSystem::GetVoiceUnlockDLLatency() */
VU_STUB(int, m5c_vu_GetVoiceUnlockDLLatency,
        "_ZN7android11AudioSystem23GetVoiceUnlockDLLatencyEv", (void), 0)

/* void* AudioSystem::getVoiceUnlockDLInstance() */
VU_STUB(void *, m5c_vu_getVoiceUnlockDLInstance,
        "_ZN7android11AudioSystem24getVoiceUnlockDLInstanceEv", (void), NULL)

/* void AudioSystem::freeVoiceUnlockDLInstance() — declared int for uniformity;
 * a discarded 0 in r0/w0 is harmless for a void caller. */
VU_STUB(int, m5c_vu_freeVoiceUnlockDLInstance,
        "_ZN7android11AudioSystem25freeVoiceUnlockDLInstanceEv", (void), 0)
