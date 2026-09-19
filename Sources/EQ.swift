import Foundation

enum FilterKind:String,CaseIterable { case peak="Peak", lowShelf="Low Shelf", highShelf="High Shelf", highPass="High Pass", lowPass="Low Pass" }
struct EQBand:Equatable {
    var kind:FilterKind
    var frequency:Double
    var gain:Double
    var q:Double
}
struct EQState:Equatable {
    var enabled:Bool, dual:Bool, btEnabled:Bool
    var left:[EQBand], right:[EQBand]
    var bass:EQBand, treble:EQBand
    static let gains=[4,7,10,13,17], frequencies=[5,8,11,14,18], qs=[6,9,12,15,19]
    init?(values:[Int:[Int:Int]],output:Int) {
        guard let l=values[output+1], let enabled=l[2], let bt=l[20], let dual=values[output]?[11] else { return nil }
        func bands(_ v:[Int:Int])->[EQBand]? {
            var result:[EQBand]=[]
            for i in 0..<5 {
                guard let f=v[Self.frequencies[i]],let g=v[Self.gains[i]],let q=v[Self.qs[i]] else { return nil }
                var kind=FilterKind.peak
                if i==0 { guard let t=v[3], (0...3).contains(t) else { return nil }; kind=[.peak,.lowShelf,.highPass,.lowPass][t] }
                if i==4 { guard let t=v[16], (0...2).contains(t) else { return nil }; kind=[.peak,.highShelf,.lowPass][t] }
                result.append(EQBand(kind:kind,frequency:Double(f),gain:Double(g)/2,q:Double(q)/10))
            }
            return result
        }
        guard let left=bands(l), let bg=l[21],let bf=l[22],let bq=l[23],let tg=l[24],let tf=l[25],let tq=l[26] else { return nil }
        let right=values[output+2].flatMap(bands)
        guard dual==0 || right != nil else { return nil }
        self.enabled=enabled==1; self.dual=dual==1; self.btEnabled=bt==1
        self.left=left; self.right=right ?? left
        bass=EQBand(kind:.lowShelf,frequency:Double(bf),gain:Double(bg)/2,q:Double(bq)/10)
        treble=EQBand(kind:.highShelf,frequency:Double(tf),gain:Double(tg)/2,q:Double(tq)/10)
    }
    func parameters(output:Int)throws->[RMEParameter] {
        var result=[RMEParameter(channel:output,index:11,value:dual ? 1 : 0),RMEParameter(channel:output+1,index:2,value:enabled ? 1 : 0),RMEParameter(channel:output+1,index:20,value:btEnabled ? 1 : 0)]
        func add(_ a:Int,_ i:Int,_ v:Double,_ scale:Double=1)throws {
            guard v.isFinite, abs(v*scale)<Double(Int.max/2) else { throw BridgeError.message(L("EQ 參數必須是有限數值", "EQ parameters must be finite numbers")) }
            let p=RMEParameter(channel:a,index:i,value:Int((v*scale).rounded()))
            guard RMEProtocol.valid(p) else { throw BridgeError.message(L("EQ 參數超出 DAC 支援範圍（參數 \(i)）", "EQ parameter out of range (parameter \(i))")) }
            result.append(p)
        }
        for (address,bands) in [(output+1,left),(output+2,right)] {
            if address==output+2 && !dual { continue }
            guard bands.count==5 else { throw BridgeError.message(L("需要 5 個 EQ 頻段", "Five EQ bands are required")) }
            for i in 0..<5 {
                let b=bands[i]
                if i==0 {
                    guard let t=[FilterKind.peak,.lowShelf,.highPass,.lowPass].firstIndex(of:b.kind) else { throw BridgeError.message(L("第一頻段類型不支援", "Unsupported filter for band 1")) }
                    try add(address,3,Double(t))
                } else if i==4 {
                    guard let t=[FilterKind.peak,.highShelf,.lowPass].firstIndex(of:b.kind) else { throw BridgeError.message(L("第五頻段類型不支援", "Unsupported filter for band 5")) }
                    try add(address,16,Double(t))
                } else if b.kind != .peak { throw BridgeError.message(L("第二至第四頻段僅支援 Peak", "Bands 2–4 support Peak filters only")) }
                try add(address,Self.gains[i],b.gain,2); try add(address,Self.frequencies[i],b.frequency); try add(address,Self.qs[i],b.q,10)
            }
        }
        try add(output+1,21,bass.gain,2); try add(output+1,22,bass.frequency); try add(output+1,23,bass.q,10)
        try add(output+1,24,treble.gain,2); try add(output+1,25,treble.frequency); try add(output+1,26,treble.q,10)
        return result
    }
    func response(frequency:Double,rightChannel:Bool=false,sampleRate:Double=44100)->Double {
        var result:Double=0
        if enabled { for b in rightChannel && dual ? right : left { result += EQResponse.decibels(b,at:frequency,sampleRate:sampleRate) } }
        if btEnabled { result += EQResponse.decibels(bass,at:frequency,sampleRate:sampleRate)+EQResponse.decibels(treble,at:frequency,sampleRate:sampleRate) }
        return result
    }
}
// RBJ biquad visualization only. The DAC performs DSP; its exact response may differ.
enum EQResponse {
    static func decibels(_ band:EQBand,at frequency:Double,sampleRate:Double)->Double {
        guard sampleRate>0, band.q>0, band.frequency>0, frequency>0 else { return 0 }
        let f=min(sampleRate*0.499,band.frequency), omega=2*Double.pi*f/sampleRate
        let c=cos(omega), s=sin(omega), alpha=s/(2*band.q), a=pow(10,band.gain/40), root=sqrt(a)
        var b0:Double=1,b1:Double=0,b2:Double=0,a0:Double=1,a1:Double=0,a2:Double=0
        switch band.kind {
        case .peak: b0=1+alpha*a; b1 = -2*c; b2=1-alpha*a; a0=1+alpha/a; a1 = -2*c; a2=1-alpha/a
        case .lowPass: b0=(1-c)/2; b1=1-c; b2=b0; a0=1+alpha; a1 = -2*c; a2=1-alpha
        case .highPass: b0=(1+c)/2; b1 = -(1+c); b2=b0; a0=1+alpha; a1 = -2*c; a2=1-alpha
        case .lowShelf:
            b0=a*((a+1)-(a-1)*c+2*root*alpha); b1=2*a*((a-1)-(a+1)*c); b2=a*((a+1)-(a-1)*c-2*root*alpha)
            a0=(a+1)+(a-1)*c+2*root*alpha; a1 = -2*((a-1)+(a+1)*c); a2=(a+1)+(a-1)*c-2*root*alpha
        case .highShelf:
            b0=a*((a+1)+(a-1)*c+2*root*alpha); b1 = -2*a*((a-1)+(a+1)*c); b2=a*((a+1)+(a-1)*c-2*root*alpha)
            a0=(a+1)-(a-1)*c+2*root*alpha; a1=2*((a-1)-(a+1)*c); a2=(a+1)-(a-1)*c-2*root*alpha
        }
        let w=2*Double.pi*min(frequency,sampleRate*0.499)/sampleRate
        let numerator=pow(b0+b1*cos(w)+b2*cos(2*w),2)+pow(b1*sin(w)+b2*sin(2*w),2)
        let denominator=pow(a0+a1*cos(w)+a2*cos(2*w),2)+pow(a1*sin(w)+a2*sin(2*w),2)
        return 10*log10(max(1e-18,numerator)/max(1e-18,denominator))
    }
}
extension Bridge {
    var eqState:EQState? { EQState(values:values,output:channel) }
    func setEQEnabled(_ enabled:Bool)throws { try send([RMEParameter(channel:eqAddress,index:2,value:enabled ? 1 : 0)]) }
    func setBTEnabled(_ enabled:Bool)throws { try send([RMEParameter(channel:eqAddress,index:20,value:enabled ? 1 : 0)]) }
    func selectPreset(_ number:Int)throws {
        guard (1...20).contains(number), !emptyPresets.contains(number) else { throw BridgeError.message(L("此 EQ 預設為空或尚未確認", "This EQ preset is empty or has not been confirmed")) }
        try send([RMEParameter(channel:eqAddress,index:28,value:number+1)])
    }
    func applyEQ(_ state:EQState)throws { try send(state.parameters(output:channel)) }
}
