#!/usr/bin/env swift
//
// Writes a PNG again at eight bits a channel, in its own colours.
// `Scripts/make-widget-icons.sh` is what runs it.
//
// **Because a picture costs what it decodes to.** Icon Composer's tool exports
// at 16 bits a channel: eight bytes a pixel in memory, where eight bits a
// channel is four. A widget extension is ended at 30 MB, and the icon at 16
// bits took one most of the way there. `Plans/PGR Widgets - iOS.md`, *The
// icon, made for widgets*.
//
// **`sips` cannot do it.** It reads `bitsPerSample` and will not set it.
//
//   swift Scripts/eight-bit-png.swift <from.png> <to.png>

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ words: String) -> Never {
    FileHandle.standardError.write(Data("eight-bit-png: \(words)\n".utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else { fail("usage: eight-bit-png.swift <from.png> <to.png>") }
let from = URL(filePath: arguments[1])
let to = URL(filePath: arguments[2])

guard let source = CGImageSourceCreateWithURL(from as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else { fail("\(from.path) is not a picture") }

// In the picture's own colours: the icon is in Display P3, and stays there.
let colours = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
guard
    let context = CGContext(
        data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
        space: colours, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { fail("no bitmap of \(image.width) by \(image.height)") }
// Copied, not drawn over anything: the corners outside the icon stay clear.
context.setBlendMode(.copy)
context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

guard let shallow = context.makeImage(),
    let written = CGImageDestinationCreateWithURL(to as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fail("could not write \(to.path)") }
CGImageDestinationAddImage(written, shallow, nil)
guard CGImageDestinationFinalize(written) else { fail("could not write \(to.path)") }
