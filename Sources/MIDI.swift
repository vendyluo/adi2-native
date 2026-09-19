import Foundation
import CoreMIDI

func midiName(_ object: MIDIObjectRef) -> String {
    var s: Unmanaged<CFString>?
    guard MIDIObjectGetStringProperty(object, kMIDIPropertyDisplayName, &s) == noErr else { return "?" }
    return s!.takeRetainedValue() as String
}
final class RMEConnection: MIDITransport {
    var client = MIDIClientRef(), input = MIDIPortRef(), output = MIDIPortRef()
    var source = MIDIEndpointRef(), destination = MIDIEndpointRef()
    var onMessage: (([UInt8]) -> Void)?
    var onTopology: (() -> Void)?
    private var framer = SysExFramer()
    init() throws {
        try check(MIDIClientCreateWithBlock("ADI2 Native" as CFString, &client) { [weak self] _ in
            DispatchQueue.main.async { self?.onTopology?() }
        }, "MIDI client")
        try check(MIDIOutputPortCreate(client, "ADI2 output" as CFString, &output), "MIDI output")
        try check(MIDIInputPortCreateWithBlock(client, "ADI2 input" as CFString, &input) { [weak self] list, _ in
            var all: [UInt8] = []
            do {
                var packet = UnsafeRawPointer(list).advanced(by: MemoryLayout<MIDIPacketList>.offset(of: \MIDIPacketList.packet)!).assumingMemoryBound(to: MIDIPacket.self)
                for _ in 0..<list.pointee.numPackets {
                    let length = Int(packet.pointee.length)
                    let data = UnsafeRawPointer(packet).advanced(by: MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data)!)
                    all += Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: length))
                    packet = UnsafePointer(MIDIPacketNext(packet))
                }
            }
            RunLoop.main.perform(inModes:[.common]) {
                guard let self = self else { return }
                for msg in self.framer.consume(all) { self.onMessage?(msg) }
            }
        }, "MIDI input")
    }
    func topologyIsCurrent() -> Bool {
        let dests = (0..<MIDIGetNumberOfDestinations()).map(MIDIGetDestination).filter { midiName($0).contains("ADI-2 DAC") }
        let sources = (0..<MIDIGetNumberOfSources()).map(MIDIGetSource).filter { midiName($0).contains("ADI-2 DAC") }
        return dests == [destination] && sources == [source] && destination != 0
    }
    func connect() throws {
        disconnect()
        let dests = (0..<MIDIGetNumberOfDestinations()).map(MIDIGetDestination).filter { midiName($0).contains("ADI-2 DAC") }
        let sources = (0..<MIDIGetNumberOfSources()).map(MIDIGetSource).filter { midiName($0).contains("ADI-2 DAC") }
        guard dests.count == 1, sources.count == 1 else { throw BridgeError.message(L("需要恰好一台 ADI-2 DAC MIDI 裝置（目前 \(dests.count) 個輸出／\(sources.count) 個輸入）", "Exactly one ADI-2 DAC MIDI device is required (\(dests.count) outputs / \(sources.count) inputs)")) }
        destination = dests[0]; source = sources[0]
        try check(MIDIPortConnectSource(input, source, nil), "Connect MIDI")
        try send(RMEProtocol.request)
    }
    func disconnect() {
        if source != 0 { MIDIPortDisconnectSource(input, source) }
        source = 0; destination = 0; framer = SysExFramer()
    }
    func send(_ bytes: [UInt8]) throws {
        guard destination != 0 else { throw BridgeError.message(L("MIDI 尚未連接", "MIDI is not connected")) }
        var list = MIDIPacketList()
        let capacity = MemoryLayout<MIDIPacketList>.size
        guard bytes.count <= 256 else { throw BridgeError.message("MIDI packet too large") }
        bytes.withUnsafeBufferPointer { data in
            withUnsafeMutablePointer(to: &list) { ptr in
                let packet = MIDIPacketListInit(ptr)
                _ = MIDIPacketListAdd(ptr, capacity, packet, 0, bytes.count, data.baseAddress!)
            }
        }
        try check(MIDISend(output, destination, &list), "MIDI send")
    }
    deinit { MIDIClientDispose(client) }
}
func check(_ status: OSStatus, _ action: String) throws {
    if status != noErr { throw BridgeError.message("\(action): OSStatus \(status)") }
}
