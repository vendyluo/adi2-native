import AppKit
import Foundation

let root = URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
let assets = root.appendingPathComponent("Assets")
try FileManager.default.createDirectory(at:assets,withIntermediateDirectories:true)
func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed:CGFloat((hex >> 16)&255)/255,green:CGFloat((hex >> 8)&255)/255,blue:CGFloat(hex&255)/255,alpha:alpha)
}
func stroke(_ points: [NSPoint], color c: NSColor, width: CGFloat) {
    let p = NSBezierPath(); p.lineWidth=width; p.lineCapStyle = .round; p.lineJoinStyle = .round
    p.move(to:points[0]); for point in points.dropFirst() { p.line(to:point) }; c.setStroke(); p.stroke()
}
func fill(_ rect: NSRect, _ radius: CGFloat, _ c: NSColor) {
    c.setFill(); NSBezierPath(roundedRect:rect,xRadius:radius,yRadius:radius).fill()
}
func appIcon() {
    let tile = NSBezierPath(roundedRect:NSRect(x:66,y:66,width:892,height:892),xRadius:200,yRadius:200)
    NSGraphicsContext.saveGraphicsState()
    let shadow=NSShadow(); shadow.shadowColor=color(0x061225,0.3); shadow.shadowBlurRadius=24; shadow.shadowOffset=NSSize(width:0,height:-10); shadow.set()
    color(0x132743).setFill(); tile.fill(); NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors:[color(0x293D62),color(0x101C32)])!.draw(in:tile,angle:-70)
    let border=NSBezierPath(roundedRect:NSRect(x:68,y:68,width:888,height:888),xRadius:198,yRadius:198)
    border.lineWidth=3; color(0xFFFFFF,0.12).setStroke(); border.stroke()
    // The same two signal terminals appear in the monochrome menu-bar mark.
    stroke([NSPoint(x:175,y:512),NSPoint(x:320,y:512)],color:color(0x72E1CE),width:24)
    stroke([NSPoint(x:704,y:512),NSPoint(x:849,y:512)],color:color(0x72E1CE),width:24)
    for x:CGFloat in [175,849] { color(0x96F5DF).setFill(); NSBezierPath(ovalIn:NSRect(x:x-19,y:493,width:38,height:38)).fill() }
    let bezel = NSBezierPath(ovalIn:NSRect(x:257,y:257,width:510,height:510))
    NSGraphicsContext.saveGraphicsState()
    let drop=NSShadow(); drop.shadowColor=color(0x000B1C,0.65); drop.shadowBlurRadius=35; drop.shadowOffset=NSSize(width:0,height:-18); drop.set()
    color(0x070E1C).setFill(); bezel.fill(); NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors:[color(0x8796AF),color(0x1B2A40),color(0x667D9B)])!.draw(in:bezel,angle:-80)
    color(0x0B1526).setFill(); NSBezierPath(ovalIn:NSRect(x:269,y:269,width:486,height:486)).fill()
    let dial=NSBezierPath(ovalIn:NSRect(x:297,y:297,width:430,height:430))
    NSGradient(colors:[color(0xF2F5F8),color(0xAAB9CB),color(0x74869F)])!.draw(in:dial,angle:-75)
    let inset=NSBezierPath(ovalIn:NSRect(x:309,y:309,width:406,height:406)); inset.lineWidth=3; color(0xFFFFFF,0.38).setStroke(); inset.stroke()
    stroke([NSPoint(x:561,y:561),NSPoint(x:633,y:633)],color:color(0x243C58),width:26)
    stroke([NSPoint(x:561,y:565),NSPoint(x:628,y:632)],color:color(0x314E6B),width:15)
    // Small luminous level tick; no lettering so the mark survives 16 px rendering.
    let tick=NSBezierPath(); tick.appendArc(withCenter:NSPoint(x:512,y:512),radius:269,startAngle:33,endAngle:57,clockwise:false)
    tick.lineWidth=13; tick.lineCapStyle = .round; color(0x82EEDA).setStroke(); tick.stroke()
}
func tray(_ tint: NSColor) {
    let dial=NSBezierPath(ovalIn:NSRect(x:4,y:3,width:12,height:12)); dial.lineWidth=1.55; tint.setStroke(); dial.stroke()
    stroke([NSPoint(x:10,y:9),NSPoint(x:13,y:12)],color:tint,width:1.7)
    stroke([NSPoint(x:1,y:9),NSPoint(x:4,y:9)],color:tint,width:1.55)
    stroke([NSPoint(x:16,y:9),NSPoint(x:19,y:9)],color:tint,width:1.55)
}
func png(width:Int,height:Int,logical:NSSize,draw:()->Void) throws -> Data {
    let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    rep.size=NSSize(width:width,height:height)
    let context=NSGraphicsContext(bitmapImageRep:rep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=context
    context.cgContext.scaleBy(x:CGFloat(width)/logical.width,y:CGFloat(height)/logical.height)
    draw(); NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using:.png,properties:[:])!
}
let iconset=assets.appendingPathComponent("AppIcon.iconset",isDirectory:true)
try FileManager.default.createDirectory(at:iconset,withIntermediateDirectories:true)
for base in [16,32,128,256,512] {
    for scale in [1,2] {
        let pixels=base*scale
        let data=try png(width:pixels,height:pixels,logical:NSSize(width:1024,height:1024),draw:appIcon)
        try data.write(to:iconset.appendingPathComponent("icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"))
        if pixels == 1024 { try data.write(to:assets.appendingPathComponent("AppIcon.png")) }
    }
}
for scale in [1,2] {
    let data=try png(width:20*scale,height:18*scale,logical:NSSize(width:20,height:18)) { tray(.black) }
    try data.write(to:assets.appendingPathComponent("StatusIconTemplate\(scale == 2 ? "@2x" : "").png"))
}
// Export a true vector PDF for NSStatusItem so arbitrary display scales stay crisp.
let pdfData=NSMutableData()
let consumer=CGDataConsumer(data:pdfData)!
var mediaBox=CGRect(x:0,y:0,width:20,height:18)
let pdf=CGContext(consumer:consumer,mediaBox:&mediaBox,nil)!
pdf.beginPDFPage(nil)
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(cgContext:pdf,flipped:false)
tray(.black); NSGraphicsContext.restoreGraphicsState(); pdf.endPDFPage(); pdf.closePDF()
try (pdfData as Data).write(to:assets.appendingPathComponent("StatusIconTemplate.pdf"))
// A compact review sheet at real menu-bar scale, plus app icon sizes.
let preview=try png(width:1100,height:600,logical:NSSize(width:1100,height:600)) {
    color(0xF1F3F7).setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:1100,height:600)).fill()
    func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ c:NSColor) {
        (s as NSString).draw(at:NSPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:c])
    }
    text("ADI2 Native",48,538,26,color(0x1D2A3D))
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current!.cgContext.translateBy(x:25,y:100); NSGraphicsContext.current!.cgContext.scaleBy(x:0.42,y:0.42); appIcon(); NSGraphicsContext.restoreGraphicsState()
    text("APP ICON",508,477,13,color(0x57657C))
    for (index,size) in [128,64,32,16].enumerated() {
        let data=try! png(width:size*2,height:size*2,logical:NSSize(width:1024,height:1024),draw:appIcon)
        NSImage(data:data)!.draw(in:NSRect(x:508+CGFloat(index)*135,y:320,width:CGFloat(size),height:CGFloat(size)))
    }
    text("MENU BAR · LIGHT / DARK",508,256,13,color(0x57657C))
    fill(NSRect(x:508,y:185,width:250,height:44),10,color(0xDCE2EA))
    fill(NSRect(x:778,y:185,width:250,height:44),10,color(0x202736))
    for (x,c) in [(CGFloat(536),color(0x172232)),(CGFloat(806),NSColor.white)] {
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current!.cgContext.translateBy(x:x,y:198); tray(c); NSGraphicsContext.restoreGraphicsState()
    }
    text("20 × 18 pt · template PDF",508,135,15,color(0x57657C))
}
try preview.write(to:assets.appendingPathComponent("IconPreview.png"))
print("Rendered app icon, iconset, vector menu-bar icon, and preview.")
