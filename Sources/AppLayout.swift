import AppKit

final class SettingsBackground:NSView { override func draw(_ dirtyRect:NSRect) { NSColor.windowBackgroundColor.setFill();dirtyRect.fill() } }
final class FlippedDocumentView:NSView { override var isFlipped:Bool { true } }

final class NavigationRow:NSTableRowView {
 override var interiorBackgroundStyle:NSView.BackgroundStyle { .normal }
 override func drawSelection(in dirtyRect:NSRect) {
  guard let context=NSGraphicsContext.current?.cgContext else { return }
  let shade:CGFloat=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? 0.25 : 0.89
  context.setFillColor(CGColor(gray:shade,alpha:1))
  context.addPath(CGPath(roundedRect:bounds.insetBy(dx:2,dy:2),cornerWidth:7,cornerHeight:7,transform:nil));context.fillPath()
 }
}

extension AppDelegate:NSTableViewDataSource,NSTableViewDelegate {
    func numberOfRows(in tableView:NSTableView)->Int { pageNames.count }
    func tableView(_ tableView:NSTableView,viewFor tableColumn:NSTableColumn?,row:Int)->NSView? {
        let cell=NSTableCellView(), icon=NSImageView(), text=NSTextField(labelWithString:pageNames[row])
        icon.image=sidebarBadge(row)
        icon.contentTintColor = nil;text.font = .systemFont(ofSize:13,weight:.medium)
        for v in [icon,text] { v.translatesAutoresizingMaskIntoConstraints=false;cell.addSubview(v) }
        NSLayoutConstraint.activate([icon.leadingAnchor.constraint(equalTo:cell.leadingAnchor,constant:10),icon.centerYAnchor.constraint(equalTo:cell.centerYAnchor),icon.widthAnchor.constraint(equalToConstant:26),icon.heightAnchor.constraint(equalToConstant:26),text.leadingAnchor.constraint(equalTo:icon.trailingAnchor,constant:10),text.centerYAnchor.constraint(equalTo:cell.centerYAnchor),text.trailingAnchor.constraint(lessThanOrEqualTo:cell.trailingAnchor,constant:-8)])
        cell.textField=text;cell.imageView=icon;text.textColor = .labelColor;icon.contentTintColor = nil;return cell
    }
    func tableView(_ tableView:NSTableView,rowViewForRow row:Int)->NSTableRowView? { NavigationRow() }
    func tableViewSelectionDidChange(_ notification:Notification) {
        for row in 0..<pageNames.count {
            if let cell=navigation.view(atColumn:0,row:row,makeIfNecessary:false) as? NSTableCellView {
                cell.textField?.textColor = .labelColor
                cell.imageView?.contentTintColor = nil
            }
        }
        displayPage(navigation.selectedRow)
        if item != nil { localizeInterface() }
    }
    func displayPage(_ index:Int) {
        guard pages.indices.contains(index) else { return }
        pageTitle.stringValue=pageNames[index]
        label.isHidden=index==2;connectionDetail.isHidden=index==2
        pageHost.subviews.forEach { $0.removeFromSuperview() }
        let page=pages[index];page.translatesAutoresizingMaskIntoConstraints=false;pageHost.addSubview(page)
        NSLayoutConstraint.activate([page.leadingAnchor.constraint(equalTo:pageHost.leadingAnchor),page.trailingAnchor.constraint(equalTo:pageHost.trailingAnchor),page.topAnchor.constraint(equalTo:pageHost.topAnchor),page.bottomAnchor.constraint(equalTo:pageHost.bottomAnchor)])
    }
    @objc func showSettings() { navigation.selectRowIndexes(IndexSet(integer:2),byExtendingSelection:false);displayPage(2);show() }
    func stack(_ views:[NSView],spacing:CGFloat=12)->NSStackView {
        let s=NSStackView(views:views);s.orientation = .vertical;s.alignment = .leading;s.spacing=spacing;return s
    }
    func text(_ value:String,size:CGFloat=13,secondary:Bool=false)->NSTextField {
        let t=NSTextField(wrappingLabelWithString:value);t.font = .systemFont(ofSize:size);t.textColor=secondary ? .secondaryLabelColor : .labelColor;t.preferredMaxLayoutWidth=700;return t
    }
    func row(_ views:[NSView])->NSStackView { let s=NSStackView(views:views);s.spacing=12;s.alignment = .centerY;return s }
    func card(_ title:String,_ views:[NSView])->NSView {
        let heading=text(title);heading.font = .systemFont(ofSize:13,weight:.semibold)
        let content=stack(views,spacing:14), box=NSBox()
        box.boxType = .custom;box.titlePosition = .noTitle;box.borderColor = .clear;box.borderWidth=0;box.cornerRadius=12;box.fillColor = NSColor(name:nil,dynamicProvider:{ $0.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? NSColor(calibratedWhite:0.16,alpha:1) : NSColor(calibratedWhite:0.967,alpha:1) });box.contentViewMargins=NSSize(width:0,height:0)
        content.translatesAutoresizingMaskIntoConstraints=false;box.contentView!.addSubview(content)
        NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo:box.contentView!.leadingAnchor,constant:20),content.trailingAnchor.constraint(equalTo:box.contentView!.trailingAnchor,constant:-20),content.topAnchor.constraint(equalTo:box.contentView!.topAnchor,constant:12),content.bottomAnchor.constraint(equalTo:box.contentView!.bottomAnchor,constant:-12)])
        for v in views where v is NSTextField { v.widthAnchor.constraint(lessThanOrEqualTo:content.widthAnchor).isActive=true }
        for v in views where v is NSStackView { v.widthAnchor.constraint(equalTo:content.widthAnchor).isActive=true }
        let group=stack([heading,box],spacing:10)
        box.widthAnchor.constraint(equalTo:group.widthAnchor).isActive=true
        return group
    }
    func scrollPage(_ views:[NSView])->NSView {
        let scroll=NSScrollView();scroll.hasVerticalScroller=true;scroll.drawsBackground=false
        let document=FlippedDocumentView(), content=stack(views,spacing:20);document.translatesAutoresizingMaskIntoConstraints=false;content.translatesAutoresizingMaskIntoConstraints=false
        scroll.documentView=document;document.addSubview(content)
        NSLayoutConstraint.activate([document.widthAnchor.constraint(equalTo:scroll.contentView.widthAnchor),content.leadingAnchor.constraint(equalTo:document.leadingAnchor,constant:24),content.trailingAnchor.constraint(equalTo:document.trailingAnchor,constant:-24),content.topAnchor.constraint(equalTo:document.topAnchor,constant:20),content.bottomAnchor.constraint(equalTo:document.bottomAnchor,constant:-24)])
        for v in views { v.widthAnchor.constraint(equalTo:content.widthAnchor).isActive=true }
        return scroll
    }
    func buildWindow() {
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:1080,height:780),styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false)
        window.titleVisibility = .hidden;window.titlebarAppearsTransparent=true;window.titlebarSeparatorStyle = .none;window.isMovableByWindowBackground=true
        window.delegate=self;window.isReleasedWhenClosed=false;window.title="ADI2 Native";window.minSize=NSSize(width:1060,height:700);window.center();window.setFrameAutosaveName("ADI2NativeMain")
        let split=NSSplitViewController(), side=NSViewController(), main=NSViewController()
        let sideView=NSVisualEffectView();sideView.material = .sidebar;sideView.blendingMode = .behindWindow;side.view=sideView
        let brand=text("ADI2 Native",size:16);brand.font = .systemFont(ofSize:16,weight:.semibold)
        let sub=text("RME ADI-2 DAC",size:11,secondary:true)
        let navScroll=NSScrollView();navScroll.drawsBackground=false;navScroll.documentView=navigation
        navigation.addTableColumn(NSTableColumn(identifier:NSUserInterfaceItemIdentifier("section")));navigation.headerView=nil;navigation.rowHeight=38;navigation.style = .plain;navigation.selectionHighlightStyle = .regular;navigation.backgroundColor = .clear;navigation.dataSource=self;navigation.delegate=self;navigation.allowsEmptySelection=false;navigation.setAccessibilityLabel(L("功能分類", "Navigation"))
        let sideStack=stack([brand,sub,navScroll],spacing:8);sideStack.translatesAutoresizingMaskIntoConstraints=false;sideView.addSubview(sideStack)
        NSLayoutConstraint.activate([sideStack.leadingAnchor.constraint(equalTo:sideView.leadingAnchor,constant:16),sideStack.trailingAnchor.constraint(equalTo:sideView.trailingAnchor,constant:-12),sideStack.topAnchor.constraint(equalTo:sideView.topAnchor,constant:64),sideStack.bottomAnchor.constraint(equalTo:sideView.bottomAnchor,constant:-20),navScroll.widthAnchor.constraint(equalTo:sideStack.widthAnchor)])
        let sideItem=NSSplitViewItem(sidebarWithViewController:side);sideItem.minimumThickness=210;sideItem.maximumThickness=230;sideItem.canCollapse=false;split.addSplitViewItem(sideItem)
        main.view=SettingsBackground();split.addSplitViewItem(NSSplitViewItem(viewController:main));window.contentViewController=split
        pageTitle.font = .systemFont(ofSize:20,weight:.semibold)
        outputs.addItems(withTitles:["Line Out · RCA／XLR","Phones · 6.3 mm","IEM · 3.5 mm"]);outputs.target=self;outputs.action=#selector(selectOutput);outputs.setAccessibilityLabel(L("控制目標", "Control target"))
        let spacer=NSView(), heading=row([pageTitle,spacer,outputs]);spacer.setContentHuggingPriority(.defaultLow,for:.horizontal)
        label.font = .systemFont(ofSize:12);label.textColor = .secondaryLabelColor
        connectionDetail.font = .systemFont(ofSize:11);connectionDetail.textColor = .secondaryLabelColor
        let header=stack([heading,label,connectionDetail],spacing:8);header.translatesAutoresizingMaskIntoConstraints=false;pageHost.translatesAutoresizingMaskIntoConstraints=false
        main.view.addSubview(header);main.view.addSubview(pageHost)
        NSLayoutConstraint.activate([header.leadingAnchor.constraint(equalTo:main.view.leadingAnchor,constant:24),header.trailingAnchor.constraint(equalTo:main.view.trailingAnchor,constant:-24),header.topAnchor.constraint(equalTo:main.view.topAnchor,constant:28),heading.widthAnchor.constraint(equalTo:header.widthAnchor),pageHost.topAnchor.constraint(equalTo:header.bottomAnchor,constant:12),pageHost.leadingAnchor.constraint(equalTo:main.view.leadingAnchor),pageHost.trailingAnchor.constraint(equalTo:main.view.trailingAnchor),pageHost.bottomAnchor.constraint(equalTo:main.view.bottomAnchor)])
        reading.font = .monospacedDigitSystemFont(ofSize:52,weight:.medium)
        volume.target=self;volume.action=#selector(slide);volume.isContinuous=true;volume.setAccessibilityLabel(L("DAC 音量，dB", "DAC volume, dB"));volume.widthAnchor.constraint(equalToConstant:680).isActive=true
        toggle.target=self;toggle.action=#selector(toggleBridge);toggle.bezelStyle = .rounded
        mute.target=self;mute.action=#selector(muteFromCheckbox)
        stepButtons=[button("−0.5 dB",#selector(quieter)),button("+0.5 dB",#selector(louder))]
        let controls=row(stepButtons+[mute])
        let live=card(L("輸出音量", "Output volume"),[reading,text(L("DAC 音量設定 · 不是房間的聲壓讀值", "DAC level · Not the sound pressure in your room"),size:12,secondary:true),volume,controls])
        let native=card(L("Mac 原生控制", "Native Mac control"),[row([toggle]),text(L("啟用後，可用鍵盤音量鍵與控制中心調整。關閉此視窗後，選單列仍會繼續控制音量。", "Use volume keys and Control Center when enabled. Menu bar control continues after you close this window."),secondary:true)])
        let reference=card(L("建立你的聆聽基準", "Your listening reference"),[text(L("固定喇叭旋鈕、座位與播放器音量，再用 DAC 調整日常音量。Apple Watch 的「噪音」讀值可作粗略參考；dBA 不能直接換算成這裡的 dB。", "Keep speaker gain, seating and player volume fixed. Use the DAC for daily adjustments. Apple Watch Noise readings are a rough reference; dBA is not the dB shown here."),secondary:true),text(L("控制目標只決定調整哪一組音量，不會切換 DAC 的實體插孔。", "The control target chooses which level to adjust. It does not switch the DAC’s physical output."),size:12,secondary:true)])
        let volumePage=scrollPage([live,native,reference])
        editor=EQEditor(bridge:bridge) { [weak self] in self?.report($0) }
        let eqPage=scrollPage([text(L("調整 DAC 內建 EQ。編輯後按「套用到 DAC」，才會改變聲音。", "Edit the DAC’s built-in EQ. Sound changes only after you apply."),secondary:true),editor.view])
        for check in [launch,restore,showDB,hideDock,openOnLaunch] { check.target=self;check.action=#selector(preferenceChanged) }
        loginStatus.font = .systemFont(ofSize:11);loginStatus.textColor = .secondaryLabelColor;loginStatus.lineBreakMode = .byWordWrapping;loginStatus.maximumNumberOfLines=0
        languagePicker.addItems(withTitles:["繁體中文","English"]);languagePicker.selectItem(at:Localization.language == "en" ? 1 : 0);languagePicker.target=self;languagePicker.action=#selector(changeLanguage)
        let startup=card(L("一般", "General"),[settingsRows([
            settingRow(L("登入時啟動", "Open at login"),launch),
            settingRow(L("啟動時顯示控制面板", "Show control panel at launch"),openOnLaunch),
            settingRow(L("恢復原生音量控制", "Restore native volume control"),restore)
        ])])
        let appearance=card(L("外觀與語言", "Appearance & language"),[settingsRows([
            settingRow(L("隱藏 Dock 圖示", "Hide Dock icon"),hideDock),
            settingRow(L("選單列顯示音量", "Show volume in menu bar"),showDB),
            settingRow(L("介面語言", "Interface language"),languagePicker)
        ])])
        floor.widthAnchor.constraint(equalToConstant:90).isActive=true;ceiling.widthAnchor.constraint(equalToConstant:90).isActive=true;floor.setAccessibilityLabel(L("滑桿下限 dB", "Slider minimum, dB"));ceiling.setAccessibilityLabel(L("音量上限 dB", "Volume ceiling, dB"))
        let range=card(L("目前輸出的音量範圍", "Volume range for this output"),[row([text(L("滑桿下限", "Slider minimum")),floor,text("dB"),text(L("音量上限", "Volume ceiling")),ceiling,text("dB")]),button(L("套用範圍", "Apply range"),#selector(applyRange)),rangeFeedback,text(L("各輸出分別記憶。上限僅在原生控制啟用時由軟體校正；硬體旋鈕可能短暫超過上限。", "Saved per output. The ceiling is enforced by software while native control is on; the hardware knob may briefly exceed it."),size:12,secondary:true)])
        rangeFeedback.isHidden=true;rangeFeedback.font = .systemFont(ofSize:11);rangeFeedback.textColor = .secondaryLabelColor
        let device=card(L("裝置連線", "Device connection"),[loginStatus,text(L("USB 重接或喚醒後會先讀取 DAC 狀態，再恢復控制。手動改選其他 Mac 輸出時，不會自動搶回。", "After USB reconnect or wake, device state is read before control resumes. Selecting another Mac output prevents automatic takeover."),secondary:true),row([button(L("重新同步", "Sync now"),#selector(resync)),button(L("重新綁定 DAC", "Pair DAC again"),#selector(rebind)),button(L("登入項目設定…", "Login Items…"),#selector(openLoginSettings))])])
        pages=[volumePage,eqPage,scrollPage([startup,appearance,range,device])]
        navigation.selectRowIndexes(IndexSet(integer:0),byExtendingSelection:false);displayPage(0)
    }
}
