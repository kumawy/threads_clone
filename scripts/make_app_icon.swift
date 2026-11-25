import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
let conversion = Process()
conversion.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
conversion.arguments = ["-s", "format", "png", project.appendingPathComponent("ThreadsClone/Resources/Assets.xcassets/threads_symbol.imageset/threads_symbol.svg").path, "--out", temporary.path]
try conversion.run()
conversion.waitUntilExit()
guard conversion.terminationStatus == 0 else { fatalError("Could not rasterize source symbol") }
defer { try? FileManager.default.removeItem(at: temporary) }
let source = CGImageSourceCreateWithURL(temporary as CFURL, nil)!
let symbol = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(gray: 16/255, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.draw(symbol, in: CGRect(x: 240, y: 192, width: 544, height: 640))
let output = CGImageDestinationCreateWithURL(destination as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(output, context.makeImage()!, nil)
guard CGImageDestinationFinalize(output) else { fatalError("Could not save app icon") }
