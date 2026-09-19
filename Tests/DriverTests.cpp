#include "ProxyAudioDevice.h"
#include <cassert>
#include <cmath>
#include <cstdio>
#include <thread>
#include <chrono>
int main() {
    ProxyAudioDevice d;
    Float32 l=-1,r=-1;
    d.calculateVolumeFactors(0.9,0.9,false,l,r); assert(l==0 && r==0);
    d.setConfigurationValue(ProxyAudioDevice::ConfigType::bridgeReady,CFSTR("1"));
    d.calculateVolumeFactors(0.9,0.9,false,l,r); assert(l==1 && r==1);
    d.calculateVolumeFactors(0.9,0.9,true,l,r); assert(l==0 && r==0);
    d.calculateVolumeFactors(0,0,false,l,r); assert(l==0 && r==0);
    d.calculateVolumeFactors(NAN,NAN,false,l,r); assert(l==0 && r==0);
    d.setConfigurationValue(ProxyAudioDevice::ConfigType::bridgeReady,CFSTR("0"));
    d.calculateVolumeFactors(0.9,0.9,false,l,r); assert(l==0 && r==0);
    d.setConfigurationValue(ProxyAudioDevice::ConfigType::bridgeReady,CFSTR("1"));
    std::this_thread::sleep_for(std::chrono::milliseconds(2100));
    d.calculateVolumeFactors(0.9,0.9,false,l,r); assert(l==0 && r==0);
    assert(d.copyDefaultProxyOutputDeviceUID()==nullptr);
    d.setConfigurationValue(ProxyAudioDevice::ConfigType::volumeRange,CFSTR("-60,-20"));
    assert(d.kVolume_MinDB.load()==-60 && d.kVolume_MaxDB.load()==-20);
    d.setConfigurationValue(ProxyAudioDevice::ConfigType::volumeRange,CFSTR("-10,-20"));
    assert(d.kVolume_MinDB.load()==-60 && d.kVolume_MaxDB.load()==-20);
    d.setConfigurationValue(ProxyAudioDevice::ConfigType::volumeRange,CFSTR("nan,0"));
    assert(d.kVolume_MinDB.load()==-60 && d.kVolume_MaxDB.load()==-20);
    puts("PASS: configurable dB range and invalid-range rejection; driver defaults silent; unity pass-through with lease; mute/zero/NaN silence; explicit stop; expired lease; no fallback device");
}
