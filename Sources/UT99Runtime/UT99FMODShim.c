// Diagnostic-only FMOD ABI shim for the no-audio startup experiment.
// It is not an audio implementation and must not be used to claim G6.

#include <stdint.h>

#define FMOD_STUB(name) intptr_t name(void) { return 0; }

FMOD_STUB(FMOD_ChannelGroup_SetMute)
FMOD_STUB(FMOD_ChannelGroup_SetVolume)
FMOD_STUB(FMOD_Channel_GetPosition)
FMOD_STUB(FMOD_Channel_IsPlaying)
FMOD_STUB(FMOD_Channel_SetLoopCount)
FMOD_STUB(FMOD_Channel_SetPan)
FMOD_STUB(FMOD_Channel_SetPaused)
FMOD_STUB(FMOD_Channel_SetPitch)
FMOD_STUB(FMOD_Channel_SetPosition)
FMOD_STUB(FMOD_Channel_SetVolume)
FMOD_STUB(FMOD_Channel_Stop)
FMOD_STUB(FMOD_DSP_Release)
FMOD_STUB(FMOD_Sound_GetDefaults)
FMOD_STUB(FMOD_Sound_GetFormat)
FMOD_STUB(FMOD_Sound_Release)
FMOD_STUB(FMOD_System_Close)
FMOD_STUB(FMOD_System_Create)
FMOD_STUB(FMOD_System_CreateChannelGroup)
FMOD_STUB(FMOD_System_CreateSound)
FMOD_STUB(FMOD_System_GetAdvancedSettings)
FMOD_STUB(FMOD_System_GetDriver)
FMOD_STUB(FMOD_System_GetDriverInfo)
FMOD_STUB(FMOD_System_GetMasterChannelGroup)
FMOD_STUB(FMOD_System_GetNumDrivers)
FMOD_STUB(FMOD_System_GetVersion)
FMOD_STUB(FMOD_System_Init)
FMOD_STUB(FMOD_System_PlaySound)
FMOD_STUB(FMOD_System_Release)
FMOD_STUB(FMOD_System_Set3DSettings)
FMOD_STUB(FMOD_System_SetAdvancedSettings)
FMOD_STUB(FMOD_System_SetDriver)
