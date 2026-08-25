// Narrow compatibility surface for the audited v469e imports.
// These legacy desktop services are optional in the startup path.  The shim
// reports them unavailable without emulating Cocoa or CoreServices.

#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>

typedef int32_t UT99Status;

UT99Status Gestalt(uint32_t selector, int32_t *response) {
    (void)selector;
    if (response) *response = 0;
    return -4; // unimpErr
}

UT99Status LSOpenCFURLRef(CFURLRef url, CFURLRef *launched_url) {
    (void)url;
    if (launched_url) *launched_url = NULL;
    return -10810; // kLSApplicationNotFoundErr
}

UT99Status NewSpeechChannel(void *synthesizer, void **channel) {
    (void)synthesizer;
    if (channel) *channel = NULL;
    return -4;
}

UT99Status DisposeSpeechChannel(void *channel) {
    (void)channel;
    return 0;
}

UT99Status SpeakText(void *channel, const void *text, uint32_t length) {
    (void)channel;
    (void)text;
    (void)length;
    return -4;
}

UT99Status SpeechBusy(void *channel) {
    (void)channel;
    return 0;
}

UT99Status StopSpeech(void *channel) {
    (void)channel;
    return 0;
}
