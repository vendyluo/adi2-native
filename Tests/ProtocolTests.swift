import Foundation
@main struct Tests {
 static func main() {
  // Known example from RME's published protocol, with DAC device ID.
  assert(RMEProtocol.set(channel:9,index:12,value:-100) == [0xF0,0,0x20,0x0D,0x71,2,0x4B,0x1F,0x1C,0xF7])
  var checks = 0
  for c in [3,6,9] {
   for v in -1145...60 {
    var msg = RMEProtocol.set(channel:c,index:12,value:v); msg[5] = 1
    assert(RMEProtocol.parameters(msg) == [RMEParameter(channel:c,index:12,value:v)])
    checks += 1
   }
   for v in 0...1 {
    var msg = RMEProtocol.set(channel:c,index:15,value:v); msg[5] = 1
    assert(RMEProtocol.parameters(msg) == [RMEParameter(channel:c,index:15,value:v)])
   }
  }
  var msg = RMEProtocol.set(channel:3,index:12,value:-100); msg[5] = 1
  for split in 0...msg.count {
   var f = SysExFramer()
   let a = f.consume(Array(msg.prefix(split))), b = f.consume(Array(msg.dropFirst(split)))
   assert(a+b == [msg])
  }
  var f = SysExFramer()
  assert(f.consume([1,2,3] + msg + [0xF8] + msg) == [msg,msg])
  assert(RMEProtocol.parameters(Array(msg.dropLast())).isEmpty)
  var other = msg; other[4] = 0x73
  assert(RMEProtocol.parameters(other).isEmpty)
  for i in 0...1000 {
   let s = Float(i)/1000
   assert(abs(RMEProtocol.scalar(RMEProtocol.decibels(s))-s) < 0.000001)
  }
  assert(RMEProtocol.decibels(1) == 0)
  assert(RMEProtocol.decibels(0) == -114.5)
  print("PASS: \(checks) volume encodings; mute, framing, foreign-device rejection, and 1,001 scalar/dB mappings")
 }
}
