import AppKit

/// A template image keeps system tint, contrast and highlighted-menu appearance.
final class StatusKnob {
    weak var button:NSStatusBarButton?
    private var timer:Timer?
    private var position=0.5, target=0.5, amplitude=0.0
    private var last=Date(), motionUntil=Date.distantPast
    private var initialized=false
    init(_ button:NSStatusBarButton?) { self.button=button }
    deinit { timer?.invalidate() }
    func update(db:Double?,range:VolumeRange) {
        guard let db else { return }
        let next=min(1,max(0,(db-range.minimum)/(range.maximum-range.minimum)))
        guard initialized else { initialized=true;position=next;target=next;render();return }
        guard abs(next-target)>0.00001 else { return }
        target=next
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { position=target;amplitude=0;timer?.invalidate();timer=nil;render();return }
        motionUntil=Date().addingTimeInterval(0.3)
        guard timer == nil else { return }
        last=Date()
        let t=Timer(timeInterval:1.0/30,repeats:true) { [weak self] _ in self?.tick() }
        timer=t;RunLoop.main.add(t,forMode:.common)
    }
    private func tick() {
        let now=Date(),dt=min(0.1,now.timeIntervalSince(last));last=now
        position += (target-position)*(1-exp(-dt*14))
        let moving=now<motionUntil || abs(target-position)>0.001
        amplitude += ((moving ? 1.0 : 0)-amplitude)*(1-exp(-dt*12))
        if !moving && amplitude<0.01 { position=target;amplitude=0;timer?.invalidate();timer=nil }
        render()
    }
    private func render() { button?.image=Self.image(position:position,amplitude:amplitude) }
    static func image(position:Double,amplitude:Double)->NSImage {
        let image=NSImage(size:NSSize(width:24,height:18),flipped:false) { _ in
            NSColor.black.setStroke()
            let ring=NSBezierPath(ovalIn:NSRect(x:5.5,y:2.5,width:13,height:13));ring.lineWidth=1.65;ring.stroke()
            let angle=(225-270*position)*Double.pi/180
            let pointer=NSBezierPath();pointer.lineWidth=1.65;pointer.lineCapStyle = .round
            pointer.move(to:NSPoint(x:12+1.5*cos(angle),y:9+1.5*sin(angle)))
            pointer.line(to:NSPoint(x:12+5.1*cos(angle),y:9+5.1*sin(angle)));pointer.stroke()
            for start in [0.5,19.5] {
                let wave=NSBezierPath();wave.lineWidth=1.4;wave.lineCapStyle = .round
                for step in 0...20 {
                    let t=Double(step)/20
                    let point=NSPoint(x:start+4*t,y:9+amplitude*1.15*sin(t*2*Double.pi))
                    if step==0 { wave.move(to:point) } else { wave.line(to:point) }
                }
                wave.stroke()
            }
            return true
        }
        image.isTemplate=true;return image
    }
}
