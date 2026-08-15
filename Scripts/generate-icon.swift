import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Assets/AppIcon.png")
let canvasSize = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvasSize)

image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Unable to create a graphics context")
}
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

let canvas = CGRect(origin: .zero, size: canvasSize)
let background = roundedRect(canvas.insetBy(dx: 28, dy: 28), radius: 224)
NSGradient(
    starting: NSColor(calibratedRed: 0.07, green: 0.14, blue: 0.31, alpha: 1),
    ending: NSColor(calibratedRed: 0.13, green: 0.31, blue: 0.55, alpha: 1)
)?.draw(in: background, angle: -48)

let shine = NSBezierPath(ovalIn: CGRect(x: 115, y: 520, width: 740, height: 370))
NSColor.white.withAlphaComponent(0.055).setFill()
shine.fill()

let shadow = roundedRect(CGRect(x: 180, y: 203, width: 664, height: 102), radius: 48)
NSColor.black.withAlphaComponent(0.22).setFill()
shadow.fill()

let laptopLid = roundedRect(CGRect(x: 185, y: 330, width: 654, height: 340), radius: 48)
NSGradient(
    starting: NSColor(calibratedWhite: 0.95, alpha: 1),
    ending: NSColor(calibratedWhite: 0.56, alpha: 1)
)?.draw(in: laptopLid, angle: -90)

let lidHighlight = roundedRect(CGRect(x: 208, y: 635, width: 608, height: 14), radius: 7)
NSColor.white.withAlphaComponent(0.58).setFill()
lidHighlight.fill()

let bezel = roundedRect(CGRect(x: 209, y: 355, width: 606, height: 286), radius: 30)
NSColor(calibratedRed: 0.15, green: 0.20, blue: 0.29, alpha: 1).setFill()
bezel.fill()

let screen = roundedRect(CGRect(x: 225, y: 371, width: 574, height: 254), radius: 20)
NSGradient(
    starting: NSColor(calibratedRed: 0.08, green: 0.17, blue: 0.32, alpha: 1),
    ending: NSColor(calibratedRed: 0.11, green: 0.35, blue: 0.48, alpha: 1)
)?.draw(in: screen, angle: -35)

let base = roundedRect(CGRect(x: 132, y: 278, width: 760, height: 92), radius: 38)
NSGradient(
    starting: NSColor(calibratedWhite: 0.91, alpha: 1),
    ending: NSColor(calibratedWhite: 0.54, alpha: 1)
)?.draw(in: base, angle: -90)

let notch = roundedRect(CGRect(x: 409, y: 293, width: 206, height: 17), radius: 8)
NSColor(calibratedWhite: 0.42, alpha: 0.65).setFill()
notch.fill()

let badgeShadow = NSBezierPath(ovalIn: CGRect(x: 603, y: 518, width: 216, height: 216))
NSColor.black.withAlphaComponent(0.22).setFill()
badgeShadow.fill()

let badge = NSBezierPath(ovalIn: CGRect(x: 590, y: 533, width: 204, height: 204))
NSGradient(
    starting: NSColor(calibratedRed: 0.20, green: 0.96, blue: 0.49, alpha: 1),
    ending: NSColor(calibratedRed: 0.02, green: 0.64, blue: 0.32, alpha: 1)
)?.draw(in: badge, angle: -90)

let clockFace = NSBezierPath(ovalIn: CGRect(x: 625, y: 568, width: 134, height: 134))
NSColor.white.withAlphaComponent(0.96).setStroke()
clockFace.lineWidth = 11
clockFace.stroke()

let hands = NSBezierPath()
hands.move(to: CGPoint(x: 692, y: 635))
hands.line(to: CGPoint(x: 692, y: 676))
hands.move(to: CGPoint(x: 692, y: 635))
hands.line(to: CGPoint(x: 726, y: 614))
NSColor.white.setStroke()
hands.lineWidth = 12
hands.lineCapStyle = .round
hands.lineJoinStyle = .round
hands.stroke()

let centerDot = NSBezierPath(ovalIn: CGRect(x: 683, y: 626, width: 18, height: 18))
NSColor.white.setFill()
centerDot.fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode PNG")
}
try png.write(to: outputURL)
