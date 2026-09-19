import AppKit

final class EQCurveView:NSView {
    var state:EQState? { didSet { needsDisplay=true } }
    var reference:EQState? { didSet { needsDisplay=true } }
    var rightChannel=false { didSet { needsDisplay=true } }
    override var intrinsicContentSize:NSSize { NSSize(width:720,height:180) }
    override func draw(_ dirtyRect:NSRect) {
        NSColor.controlBackgroundColor.setFill(); NSBezierPath(roundedRect:bounds,xRadius:10,yRadius:10).fill()
        let plot=bounds.insetBy(dx:38,dy:24)
        func x(_ hz:Double)->CGFloat { plot.minX+CGFloat(log10(hz/20)/3)*plot.width }
        func y(_ gain:Double)->CGFloat { plot.midY+CGFloat(max(-18,min(18,gain))/36)*plot.height }
        let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:10),.foregroundColor:NSColor.secondaryLabelColor]
        for gain in [-12,0,12] {
            let p=NSBezierPath();p.move(to:NSPoint(x:plot.minX,y:y(Double(gain))));p.line(to:NSPoint(x:plot.maxX,y:y(Double(gain))))
            (gain==0 ? NSColor.separatorColor : NSColor.quaternaryLabelColor).setStroke();p.stroke()
            ("\(gain)" as NSString).draw(at:NSPoint(x:5,y:y(Double(gain))-6),withAttributes:attrs)
        }
        for hz in [20.0,100,1000,10000,20000] {
            let p=NSBezierPath();p.move(to:NSPoint(x:x(hz),y:plot.minY));p.line(to:NSPoint(x:x(hz),y:plot.maxY));NSColor.quaternaryLabelColor.setStroke();p.stroke()
            ((hz>=1000 ? "\(Int(hz/1000))k" : "\(Int(hz))") as NSString).draw(at:NSPoint(x:x(hz)-10,y:5),withAttributes:attrs)
        }
        if let reference {
            let original=NSBezierPath();original.lineWidth=1.3;original.setLineDash([4,3],count:2,phase:0)
            for i in 0...300 {
                let hz=20*pow(1000,Double(i)/300),p=NSPoint(x:x(hz),y:y(reference.response(frequency:hz,rightChannel:rightChannel)))
                if i==0 { original.move(to:p) } else { original.line(to:p) }
            }
            NSColor.secondaryLabelColor.setStroke();original.stroke()
        }
        guard let state=state else { return }
        let path=NSBezierPath();path.lineWidth=2.2
        for i in 0...300 {
            let hz=20*pow(1000,Double(i)/300), p=NSPoint(x:x(hz),y:y(state.response(frequency:hz,rightChannel:rightChannel)))
            if i==0 { path.move(to:p) } else { path.line(to:p) }
        }
        NSColor.controlAccentColor.setStroke();path.stroke()
    }
}
final class EQEditor:NSObject,NSTextFieldDelegate {
    let view=NSStackView()
    let bridge:Bridge
    let report:(Error)->Void
    var draft:EQState?, baseline:EQState?
    var output:Int=0, dirty=false, pendingApply=false
    var shownRight=false
    var expected:[RMEParameter]=[]
    var validationMessage:String?
    var applyFailure:String?
    let discard=NSButton(title:L("撤銷草稿", "Discard edits"),target:nil,action:nil)
    let compare=NSButton(checkboxWithTitle:L("對照原始曲線", "Compare original curve"),target:nil,action:nil)
    let curve=EQCurveView(), message=NSTextField(wrappingLabelWithString:L("等待 EQ 設定…", "Waiting for EQ settings…"))
    let enabled=NSButton(checkboxWithTitle:"EQ",target:nil,action:nil)
    let dual=NSButton(checkboxWithTitle:L("左右獨立 EQ", "Separate left / right EQ"),target:nil,action:nil)
    let bt=NSButton(checkboxWithTitle:"Bass／Treble",target:nil,action:nil)
    let side=NSPopUpButton(), preset=NSPopUpButton()
    var types:[NSPopUpButton]=[], frequencies:[NSTextField]=[], gains:[NSTextField]=[], qs:[NSTextField]=[]
    var btFields:[NSTextField]=[]
    let apply=NSButton(title:L("套用到 DAC", "Apply to DAC"),target:nil,action:nil)
    let reload=NSButton(title:L("重新讀取", "Reload"),target:nil,action:nil)
    init(bridge:Bridge,report:@escaping(Error)->Void) {
        self.bridge=bridge;self.report=report;super.init()
        view.orientation = .vertical;view.alignment = .leading;view.spacing=12
        let header=NSStackView(); header.spacing=14
        for button in [enabled,dual,bt] { button.target=self;button.action=#selector(changed);header.addArrangedSubview(button) }
        side.addItems(withTitles:[L("左／雙聲道", "Left / stereo"),L("右聲道", "Right")]);side.target=self;side.action=#selector(sideChanged);header.addArrangedSubview(side)
        preset.addItem(withTitle:L("載入 DAC EQ 預設…", "Load DAC EQ preset…"))
        for n in 1...20 { preset.addItem(withTitle:L("\(n). 讀取中…", "\(n). Loading…"));preset.lastItem?.tag=n }
        preset.target=self;preset.action=#selector(presetChanged);header.addArrangedSubview(preset)
        view.addArrangedSubview(header)
        view.addArrangedSubview(curve);curve.widthAnchor.constraint(equalToConstant:736).isActive=true;curve.heightAnchor.constraint(equalToConstant:180).isActive=true
        let caption=NSTextField(labelWithString:L("頻率響應示意（RBJ 模型）；實際聲音由 DAC 處理，曲線不含 Loudness 等其他 DSP。", "Approximate response (RBJ model). DSP runs on the DAC; Loudness and other processing are not shown."))
        caption.font = .systemFont(ofSize:11);caption.textColor = .secondaryLabelColor;view.addArrangedSubview(caption)
        var rows:[[NSView]]=[[NSTextField(labelWithString:L("頻段", "Band")),NSTextField(labelWithString:L("類型", "Type")),NSTextField(labelWithString:L("頻率 Hz", "Frequency Hz")),NSTextField(labelWithString:L("增益 dB", "Gain dB")),NSTextField(labelWithString:"Q")]]
        for i in 0..<5 {
            let type=NSPopUpButton()
            let kinds:[FilterKind]=i==0 ? [.peak,.lowShelf,.highPass,.lowPass] : (i==4 ? [.peak,.highShelf,.lowPass] : [.peak])
            type.addItems(withTitles:kinds.map(\.rawValue));type.target=self;type.action=#selector(changed)
            type.widthAnchor.constraint(equalToConstant:145).isActive=true
            let f=field(),g=field(),q=field();types.append(type);frequencies.append(f);gains.append(g);qs.append(q)
            rows.append([NSTextField(labelWithString:"Band \(i+1)"),type,f,g,q])
        }
        for name in ["Bass","Treble"] {
            let f=field(),g=field(),q=field();btFields += [f,g,q]
            rows.append([NSTextField(labelWithString:name),NSTextField(labelWithString:name == "Bass" ? "Low Shelf" : "High Shelf"),f,g,q])
        }
        let grid=NSGridView(views:rows);grid.rowSpacing=8;grid.columnSpacing=16
        for (index,width) in [70.0,150.0,140.0,140.0,120.0].enumerated() { grid.column(at:index).width=CGFloat(width);grid.column(at:index).xPlacement = .leading }
        view.addArrangedSubview(grid)
        let actions=NSStackView();actions.spacing=12
        apply.target=self;apply.action=#selector(applyChanges);reload.target=self;reload.action=#selector(reloadHardware)
        discard.target=self;discard.action=#selector(discardDraft);compare.target=self;compare.action=#selector(compareChanged)
        actions.addArrangedSubview(apply);actions.addArrangedSubview(discard);actions.addArrangedSubview(reload);actions.addArrangedSubview(compare);view.addArrangedSubview(actions)
        message.font = .systemFont(ofSize:12);message.textColor = .secondaryLabelColor
        message.preferredMaxLayoutWidth=730;view.addArrangedSubview(message)
        refresh()
    }
    func field()->NSTextField {
        let f=NSTextField(string:"");f.widthAnchor.constraint(equalToConstant:95).isActive=true
        f.delegate=self;f.target=self;f.action=#selector(changed);return f
    }
    func number(_ f:NSTextField)throws->Double {
        guard let d=Double(f.stringValue.trimmingCharacters(in:.whitespaces)),d.isFinite else { throw BridgeError.message(L("請輸入有效數字", "Enter a valid number")) };return d
    }
    func capture()throws->EQState {
        guard var state=draft else { throw BridgeError.message(L("尚未讀取 EQ", "EQ has not been loaded")) }
        var bands=shownRight ? state.right : state.left
        for i in 0..<5 {
            bands[i]=EQBand(kind:FilterKind(rawValue:types[i].titleOfSelectedItem ?? "Peak") ?? .peak,frequency:try number(frequencies[i]),gain:try number(gains[i]),q:try number(qs[i]))
        }
        if shownRight { state.right=bands } else { state.left=bands }
        state.enabled=enabled.state == .on;state.dual=dual.state == .on;state.btEnabled=bt.state == .on
        state.bass=EQBand(kind:.lowShelf,frequency:try number(btFields[0]),gain:try number(btFields[1]),q:try number(btFields[2]))
        state.treble=EQBand(kind:.highShelf,frequency:try number(btFields[3]),gain:try number(btFields[4]),q:try number(btFields[5]))
        _ = try state.parameters(output:bridge.channel)
        return state
    }
    func paintFields() {
        guard let s=draft else { return }
        enabled.state=s.enabled ? .on : .off;dual.state=s.dual ? .on : .off;bt.state=s.btEnabled ? .on : .off
        side.isEnabled=s.dual;side.selectItem(at:shownRight ? 1 : 0)
        let bands=shownRight ? s.right : s.left
        for i in 0..<5 { types[i].selectItem(withTitle:bands[i].kind.rawValue);frequencies[i].stringValue=String(format:"%.0f",bands[i].frequency);gains[i].stringValue=String(format:"%.1f",bands[i].gain);qs[i].stringValue=String(format:"%.1f",bands[i].q) }
        for (offset,b) in [(0,s.bass),(3,s.treble)] { btFields[offset].stringValue=String(format:"%.0f",b.frequency);btFields[offset+1].stringValue=String(format:"%.1f",b.gain);btFields[offset+2].stringValue=String(format:"%.1f",b.q) }
        curve.state=s;curve.rightChannel=shownRight
    }
    func refresh() {
        let state=bridge.eqState
        if output != bridge.channel { output=bridge.channel;dirty=false;baseline=nil;draft=nil;shownRight=false }
        if pendingApply && !bridge.hasPending {
            pendingApply=false
            if !expected.isEmpty && expected.allSatisfy({ bridge.values[$0.channel]?[$0.index] == $0.value }) {
                dirty=false;baseline=nil;applyFailure=nil
            } else { dirty=true;applyFailure=L("DAC 尚未確認全部設定；草稿已保留。請重新連線或讀取後再試。", "DAC has not confirmed all settings. Your draft is kept. Reconnect or reload before trying again.") }
            expected=[]
        }
        if !dirty && state != baseline { baseline=state;draft=state;paintFields() }
        let editable=bridge.connected && state != nil && !pendingApply
        for c in [enabled,dual,bt] { c.isEnabled=editable }
        for f in frequencies+gains+qs+btFields { f.isEnabled=editable }
        for t in types { t.isEnabled=editable }
        side.isEnabled=editable && (draft?.dual ?? false)
        apply.isEnabled=editable && dirty && validationMessage == nil && state==baseline
        discard.isEnabled=dirty && !pendingApply
        compare.isEnabled=baseline != nil
        curve.reference=compare.state == .on ? baseline : nil
        reload.isEnabled=bridge.connected
        preset.isEnabled=bridge.connected && !dirty && !pendingApply
        for n in 1...20 {
            let name=bridge.presetNames[n] ?? L("讀取中…", "Loading…")
            preset.item(at:n)?.title="\(n). \(name.isEmpty ? L("未命名", "Unnamed") : name)\(bridge.emptyPresets.contains(n) ? L("（空白）", " (empty)") : "")"
            preset.item(at:n)?.isEnabled=bridge.presetNames[n] != nil && !bridge.emptyPresets.contains(n)
        }
        if let validationMessage { message.stringValue=validationMessage }
        else if let applyFailure { message.stringValue=applyFailure }
        else if pendingApply { message.stringValue=L("等待 DAC 確認 EQ 設定…", "Waiting for DAC to confirm EQ…") }
        else if dirty && state != baseline { message.stringValue=L("硬體 EQ 已在別處變更；請先重新讀取，再套用編輯。", "EQ changed on the device. Reload before applying your edits.") }
        else if dirty { message.stringValue=L("尚未套用。增益步階 0.5 dB、Q 步階 0.1；高頻依硬體協定以 10 Hz 編碼。", "Not applied · Gain: 0.5 dB steps; Q: 0.1 steps; high frequencies: 10 Hz steps.") }
        else { message.stringValue=state == nil ? L("等待完整 EQ 資料…", "Waiting for complete EQ data…") : L("已同步 \(bridge.channelName)。套用只變更目前 EQ，不覆寫 DAC 儲存的預設。", "Synced with \(bridge.channelName). Apply changes the current EQ, not stored presets.") }
    }
    func controlTextDidChange(_ notification:Notification) { changed() }
    @objc func changed() {
        guard draft != nil else { return }
        dirty=true;applyFailure=nil
        do { let state=try capture();draft=state;if !state.dual && shownRight { shownRight=false;paintFields() };curve.state=state;side.isEnabled=state.dual;validationMessage=nil }
        catch { validationMessage=L("輸入尚未完成或超出範圍：\(error)", "Incomplete or out-of-range input: \(error)") }
        refresh()
    }
    @objc func sideChanged() {
        do { draft=try capture();shownRight=side.indexOfSelectedItem==1;paintFields() }
        catch { side.selectItem(at:shownRight ? 1 : 0);report(error) }
    }
    @objc func compareChanged() { curve.reference=compare.state == .on ? baseline : nil }
    @objc func discardDraft() {
        dirty=false;validationMessage=nil;applyFailure=nil;draft=bridge.eqState;baseline=bridge.eqState;paintFields();refresh()
    }
    @objc func reloadHardware() {
        validationMessage=nil;applyFailure=nil;expected=[]
        dirty=false;pendingApply=false;baseline=nil;draft=bridge.eqState;refresh()
        do { try bridge.requestSettings() } catch { report(error) }
    }
    @objc func applyChanges() {
        do {
            guard bridge.eqState==baseline else { throw BridgeError.message(L("硬體 EQ 已變動，請先重新讀取", "Device EQ changed. Reload first.")) }
            let state=try capture();expected=try state.parameters(output:bridge.channel).map(RMEProtocol.normalized);applyFailure=nil;pendingApply=true;try bridge.applyEQ(state);refresh()
        } catch { pendingApply=false;expected=[];applyFailure=String(describing:error);refresh();report(error) }
    }
    @objc func presetChanged() {
        let n=preset.selectedTag();preset.selectItem(at:0)
        guard n>0 else { return }
        do { try bridge.selectPreset(n) } catch { report(error) }
    }
}
