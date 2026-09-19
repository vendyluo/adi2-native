import AppKit

extension AppDelegate {
    @objc func changeLanguage() {
        Localization.language=languagePicker.indexOfSelectedItem==1 ? "en" : "zh-Hant"
        settings.defaults.set(Localization.language,forKey:"interfaceLanguage")
        let selected=max(0,navigation.selectedRow)
        navigation.reloadData();navigation.selectRowIndexes(IndexSet(integer:selected),byExtendingSelection:false)
        pageTitle.stringValue=pageNames[selected]
        refresh(force:true)
    }
    func localizeInterface() {
        func menu(_ m:NSMenu) {
            for i in m.items {
                if !(1...20).contains(i.tag) { i.title=Localization.translated(i.title) }
                if let sub=i.submenu { menu(sub) }
            }
        }
        func walk(_ v:NSView) {
            if let f=v as? NSTextField, !f.isEditable { f.stringValue=Localization.translated(f.stringValue) }
            if let p=v as? NSPopUpButton {
                if p === editor.preset { if let first=p.item(at:0) { first.title=Localization.translated(first.title) } }
                else if p !== languagePicker, let m=p.menu { menu(m) }
            } else if let b=v as? NSButton { b.title=Localization.translated(b.title) }
            if let label=v.accessibilityLabel() { v.setAccessibilityLabel(Localization.translated(label)) }
            for child in v.subviews { walk(child) }
        }
        if let content=window?.contentView { walk(content) }
        for page in pages { walk(page) }
        if let m=item?.menu { menu(m) }
        if let m=NSApp.mainMenu { menu(m) }
    }
    func sidebarBadge(_ index:Int)->NSImage {
        let colors:[NSColor]=[.systemBlue,.systemPurple,.systemOrange]
        let symbol=["speaker.wave.2.fill","slider.horizontal.3","gearshape.fill"][index]
        return NSImage(size:NSSize(width:26,height:26),flipped:false) { _ in
            colors[index].setFill();NSBezierPath(roundedRect:NSRect(x:1,y:1,width:24,height:24),xRadius:6,yRadius:6).fill()
            let icon=NSImage(systemSymbolName:symbol,accessibilityDescription:nil)?.withSymbolConfiguration(.init(paletteColors:[.white]))
            icon?.draw(in:NSRect(x:5,y:5,width:16,height:16));return true
        }
    }
    func settingRow(_ title:String,_ control:NSView)->NSView {
        let label=text(title),spacer=NSView(),line=row([label,spacer,control])
        label.font = .systemFont(ofSize:13)
        control.setAccessibilityLabel(title)
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1),for:.horizontal)
        spacer.widthAnchor.constraint(greaterThanOrEqualToConstant:16).isActive=true
        line.heightAnchor.constraint(greaterThanOrEqualToConstant:38).isActive=true
        return line
    }
    func settingsRows(_ rows:[NSView])->NSStackView {
        let group=stack([],spacing:0)
        for (index,row) in rows.enumerated() {
            if index>0 { let line=NSBox();line.boxType = .separator;line.heightAnchor.constraint(equalToConstant:1).isActive=true;group.addArrangedSubview(line);line.widthAnchor.constraint(equalTo:group.widthAnchor).isActive=true }
            group.addArrangedSubview(row);row.widthAnchor.constraint(equalTo:group.widthAnchor).isActive=true
        }
        return group
    }
}
