#include "AudioDevice.h"
#include <cassert>
#include <cstdio>
static UInt32 streams=2;
static bool failQuery=false,failSet=false,failStart=false;
static int configured=0,started=0,destroyed=0;
static OSStatus createProc(AudioDeviceID,AudioDeviceIOProc,void*,AudioDeviceIOProcID *p) { *p=reinterpret_cast<AudioDeviceIOProcID>(uintptr_t(1));return noErr; }
static OSStatus destroyProc(AudioDeviceID,AudioDeviceIOProcID) { ++destroyed;return noErr; }
static OSStatus startProc(AudioDeviceID,AudioDeviceIOProcID) { ++started;return failStart ? kAudioHardwareUnspecifiedError : noErr; }
static OSStatus querySize(AudioObjectID,const AudioObjectPropertyAddress *a,UInt32,const void*,UInt32 *size) {
 assert(a->mSelector==kAudioDevicePropertyStreams && a->mScope==kAudioObjectPropertyScopeInput);
 *size=streams*sizeof(AudioStreamID);return failQuery ? kAudioHardwareUnspecifiedError : noErr;
}
static OSStatus setData(AudioObjectID,const AudioObjectPropertyAddress *a,UInt32,const void*,UInt32 size,const void *data) {
 assert(a->mSelector==kAudioDevicePropertyIOProcStreamUsage && a->mScope==kAudioObjectPropertyScopeInput);
 auto *u=static_cast<const AudioHardwareIOProcStreamUsage*>(data);
 assert(u->mNumberStreams==streams && u->mIOProc==reinterpret_cast<void*>(uintptr_t(1)));
 assert(size==offsetof(AudioHardwareIOProcStreamUsage,mStreamIsOn)+streams*sizeof(UInt32));
 for(UInt32 i=0;i<streams;++i) assert(u->mStreamIsOn[i]==0);
 ++configured;return failSet ? kAudioHardwareUnspecifiedError : noErr;
}
#define AudioDeviceCreateIOProcID createProc
#define AudioDeviceDestroyIOProcID destroyProc
#define AudioDeviceStart startProc
#define AudioObjectGetPropertyDataSize querySize
#define AudioObjectSetPropertyData setData
#include "../Vendor/shared/AudioDevice.cpp"
int main() {
 AudioDevice d;d.id=123;
 d.setupIOProc(nullptr,nullptr);assert(configured==1);d.start();assert(started==1);d.destroyIOProc();d.isStarted=false;
 failSet=true;d.setupIOProc(nullptr,nullptr);assert(d.procId==nullptr);d.start();assert(started==1);
 failSet=false;failQuery=true;d.setupIOProc(nullptr,nullptr);assert(d.procId==nullptr);d.start();assert(started==1);
 failQuery=false;streams=0;d.setupIOProc(nullptr,nullptr);d.start();assert(started==2);d.destroyIOProc();
 assert(destroyed==4);
 d.isStarted=false;streams=2;failSet=true;d.setupIOProc(nullptr,nullptr);
 assert(d.lastIOError!=noErr && d.procId==nullptr);
 failSet=false;d.setupIOProc(nullptr,nullptr);assert(d.procId!=nullptr && d.lastIOError==noErr);
 failStart=true;d.start();assert(!d.isStarted && d.lastIOError!=noErr);
 failStart=false;d.start();assert(d.isStarted && d.lastIOError==noErr);d.destroyIOProc();
 puts("PASS: input setup failure is observable and retryable on the same device; start failure is observable and recovers");
 puts("PASS: all capture streams disabled before playback; query/set failures prevent start; output-only devices supported");
}
