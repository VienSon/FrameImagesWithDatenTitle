import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct MetadataRecord: Sendable {
    let filename: String
    let captureDate: String
    let title: String
}

struct MetadataRow: Identifiable, Hashable {
    let id: String
    let filename: String
    var captureDate: String
    var title: String
    let originalCaptureDate: String
    let originalTitle: String

    var isEdited: Bool {
        captureDate != originalCaptureDate || title != originalTitle
    }
}

struct RenderSettings: Sendable {
    let borderMode: BorderMode
    let border: Double
    let bottom: Double
    let pad: Int
    let dateFont: Int
    let titleFont: Int
    let titleFontChoice: TitleFontChoice
    let textLayout: TextLayoutMode
}

struct ProcessSummary: Sendable {
    let success: Int
    let total: Int
    var failed: Int { total - success }
}

enum BorderMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case pixels
    case percent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pixels:
            return "Pixels"
        case .percent:
            return "Percent"
        }
    }

    var unitLabel: String {
        switch self {
        case .pixels:
            return "px"
        case .percent:
            return "%"
        }
    }
}

enum TitleFontChoice: String, CaseIterable, Identifiable, Sendable, Codable {
    case inter
    case notoSans
    case notoSerif
    case sourceSerif4

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .inter:
            return "Inter Regular"
        case .notoSans:
            return "NotoSans Regular"
        case .notoSerif:
            return "NotoSerif Regular"
        case .sourceSerif4:
            return "Source Serif 4 Regular"
        }
    }

    var fileName: String {
        switch self {
        case .inter:
            return "Inter-Variable.ttf"
        case .notoSans:
            return "NotoSans-Variable.ttf"
        case .notoSerif:
            return "NotoSerif-Variable.ttf"
        case .sourceSerif4:
            return "SourceSerif4-Regular.ttf"
        }
    }

    var fallbackPostScriptName: String {
        switch self {
        case .inter:
            return "HelveticaNeue"
        case .notoSans:
            return "Helvetica"
        case .notoSerif:
            return "TimesNewRomanPSMT"
        case .sourceSerif4:
            return "TimesNewRomanPSMT"
        }
    }
}

struct SavedSettingPreset: Codable {
    let borderMode: BorderMode
    let border: String
    let bottom: String
    let pad: String
    let dateFont: String
    let titleFont: String
    let titleFontChoice: TitleFontChoice
    let textLayout: TextLayoutMode
}

enum TextLayoutMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case stacked
    case row

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stacked:
            return "Stacked"
        case .row:
            return "Same Row"
        }
    }
}

enum NativeFrameProcessor {
    static let imageExtensions: Set<String> = [".jpg", ".jpeg", ".tif", ".tiff", ".png"]
    static let embeddedXMPHeadBytes = 2_000_000
    static let embeddedXMPMaxFullReadBytes = 25_000_000

    private static let xmpTitleRegex = try? NSRegularExpression(
        pattern: #"<dc:title>\s*<rdf:Alt>\s*<rdf:li[^>]*>(.*?)</rdf:li>\s*</rdf:Alt>\s*</dc:title>"#,
        options: [.dotMatchesLineSeparators, .caseInsensitive]
    )
    private static let xmlTagRegex = try? NSRegularExpression(pattern: #"<[^>]+>"#)

    static let exifInputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f
    }()

    static let exifOutputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func scan(inputDir: URL) throws -> [MetadataRecord] {
        let files = try imageFiles(in: inputDir, invalidInputCode: 1)

        return files.map { url in
            MetadataRecord(
                filename: url.lastPathComponent,
                captureDate: readCaptureDate(url) ?? "",
                title: readTitle(url) ?? ""
            )
        }
    }

    static func processFolder(
        inputDir: URL,
        outputDir: URL,
        settings: RenderSettings,
        metadataOverrides: [String: (String, String)],
        includeFilenames: Set<String>,
        progress: @escaping (_ done: Int, _ total: Int) -> Void,
        log: @escaping (_ line: String) -> Void
    ) throws -> ProcessSummary {
        let files = try imageFiles(in: inputDir, invalidInputCode: 2).filter { includeFilenames.contains($0.lastPathComponent) }
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let total = files.count
        progress(0, total)

        var success = 0
        for (idx, fileURL) in files.enumerated() {
            let filename = fileURL.lastPathComponent
            let override = metadataOverrides[filename]
            let dateText = override?.0 ?? readCaptureDate(fileURL) ?? ""
            let titleText = override?.1 ?? readTitle(fileURL) ?? ""

            do {
                let out = try renderAndSave(
                    srcURL: fileURL,
                    outDir: outputDir,
                    dateText: dateText,
                    title: titleText,
                    settings: settings
                )
                success += 1
                log("Saved: \(out.path)")
            } catch {
                log("ERROR: Failed processing \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }

            progress(idx + 1, total)
        }

        log("Done. Processed \(total) file(s), succeeded \(success), failed \(total - success).")
        return ProcessSummary(success: success, total: total)
    }

    private static func readCaptureDate(_ url: URL) -> String? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
            return nil
        }

        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let raw = exif[kCGImagePropertyExifDateTimeOriginal] as? String,
           let date = exifInputFormatter.date(from: raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return exifOutputFormatter.string(from: date)
        }

        if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let raw = tiff[kCGImagePropertyTIFFDateTime] as? String,
           let date = exifInputFormatter.date(from: raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return exifOutputFormatter.string(from: date)
        }

        return nil
    }

    private static func readTitle(_ url: URL) -> String? {
        let sidecar = url.deletingPathExtension().appendingPathExtension("xmp")
        if let data = try? Data(contentsOf: sidecar, options: [.mappedIfSafe]),
           let title = readXMPTitle(data: data),
           !title.isEmpty {
            return title
        }

        // Read only the first chunk for embedded XMP first to avoid loading huge images into RAM.
        if let handle = try? FileHandle(forReadingFrom: url) {
            defer { try? handle.close() }

            if let head = try? handle.read(upToCount: embeddedXMPHeadBytes),
               let title = readXMPTitle(data: head), !title.isEmpty {
                return title
            }

            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let fileSize = attrs[.size] as? NSNumber,
               fileSize.intValue <= embeddedXMPMaxFullReadBytes,
               let full = try? Data(contentsOf: url, options: [.mappedIfSafe]),
               let title = readXMPTitle(data: full),
               !title.isEmpty {
                return title
            }
        }

        return nil
    }

    private static func readXMPTitle(data: Data) -> String? {
        let s = String(decoding: data, as: UTF8.self)
        guard let re = xmpTitleRegex else {
            return nil
        }

        let range = NSRange(location: 0, length: s.utf16.count)
        guard let match = re.firstMatch(in: s, options: [], range: range), match.numberOfRanges > 1,
              let bodyRange = Range(match.range(at: 1), in: s) else {
            return nil
        }

        var text = String(s[bodyRange])
        if let tagRe = xmlTagRegex {
            let full = NSRange(location: 0, length: text.utf16.count)
            text = tagRe.stringByReplacingMatches(in: text, options: [], range: full, withTemplate: "")
        }

        text = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")

        let normalized = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.isEmpty ? nil : normalized
    }

    private static func renderAndSave(
        srcURL: URL,
        outDir: URL,
        dateText: String,
        title: String,
        settings: RenderSettings
    ) throws -> URL {
        guard let src = CGImageSourceCreateWithURL(srcURL as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw NSError(domain: "FrameMacApp", code: 10, userInfo: [NSLocalizedDescriptionKey: "Could not load image"])
        }

        let w = cg.width
        let h = cg.height

        let borderInput = max(0.0, settings.border)
        let bottomInput = max(0.0, settings.bottom)
        let border: Int
        let bottom: Int
        switch settings.borderMode {
        case .pixels:
            border = max(0, Int(borderInput.rounded()))
            bottom = max(0, Int(bottomInput.rounded()))
        case .percent:
            border = max(0, Int((Double(w) * Double(borderInput) / 100.0).rounded()))
            bottom = max(0, Int((Double(w) * Double(bottomInput) / 100.0).rounded()))
        }
        let pad = max(0, settings.pad)

        let dateTextTrimmed = dateText.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleTrimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        let titleFont = loadFont(
            fileName: settings.titleFontChoice.fileName,
            size: CGFloat(max(1, settings.titleFont)),
            fallbackName: settings.titleFontChoice.fallbackPostScriptName
        )
        let dateFont: CTFont
        if settings.textLayout == .row {
            dateFont = titleFont
        } else {
            dateFont = loadFont(fileName: "JetBrainsMono-Regular.ttf", size: CGFloat(max(1, settings.dateFont)), fallbackName: "Menlo")
        }

        let textMaxW = max(1, w - (pad * 2))
        let gap = max(4, Int(Double(max(1, settings.titleFont)) * 0.35))
        let topOffset = max(0, Int(Double(bottom) * 0.18))

        let dateH = Int(ceil(lineHeight(dateFont)))
        let titleH = Int(ceil(lineHeight(titleFont)))
        let titleLinesStacked = titleTrimmed.isEmpty ? [] : wrapText(titleTrimmed, font: titleFont, maxWidth: CGFloat(textMaxW))
        let titleBlockHStacked = titleLinesStacked.count * titleH + max(0, titleLinesStacked.count - 1) * gap
        var contentH = topOffset
        var titleLinesToDraw = titleLinesStacked
        var drawInRow = false

        if settings.textLayout == .row, !dateTextTrimmed.isEmpty, !titleTrimmed.isEmpty {
            let dateW = Int(ceil(textWidth(dateTextTrimmed, font: dateFont)))
            let rowGap = max(12, Int(Double(max(1, settings.titleFont)) * 0.25))
            let titleStartX = dateW + rowGap
            let titleW = max(1, textMaxW - titleStartX)
            let titleLinesRow = wrapText(titleTrimmed, font: titleFont, maxWidth: CGFloat(titleW))
            let titleBlockHRow = titleLinesRow.count * titleH + max(0, titleLinesRow.count - 1) * gap
            contentH += max(dateH, titleBlockHRow)
            contentH += max(0, topOffset / 2)
            titleLinesToDraw = titleLinesRow
            drawInRow = true
        } else {
            if !dateTextTrimmed.isEmpty {
                contentH += dateH
                if !titleLinesStacked.isEmpty {
                    contentH += gap
                }
            }
            contentH += titleBlockHStacked
            contentH += max(0, topOffset / 2)
        }

        let actualBottom = max(bottom, contentH)

        let newW = w + border * 2
        let newH = h + border * 2 + actualBottom

        guard let ctx = CGContext(
            data: nil,
            width: newW,
            height: newH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "FrameMacApp", code: 11, userInfo: [NSLocalizedDescriptionKey: "Could not create drawing context"])
        }

        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: newW, height: newH))

        // Draw source image near the top with configured border.
        ctx.draw(cg, in: CGRect(x: border, y: actualBottom + border, width: w, height: h))

        let textColor = CGColor(gray: 0.16, alpha: 1)
        var yTop = border + h + topOffset
        let xLeft = CGFloat(border + pad)
        let rowGap = max(12, Int(Double(max(1, settings.titleFont)) * 0.25))

        if drawInRow {
            drawTextLine(
                dateTextTrimmed,
                font: dateFont,
                color: textColor,
                x: xLeft,
                yTop: yTop,
                canvasHeight: newH,
                in: ctx
            )
            let dateW = Int(ceil(textWidth(dateTextTrimmed, font: dateFont)))
            let titleX = xLeft + CGFloat(dateW + rowGap)
            for line in titleLinesToDraw {
                drawTextLine(
                    line,
                    font: titleFont,
                    color: textColor,
                    x: titleX,
                    yTop: yTop,
                    canvasHeight: newH,
                    in: ctx
                )
                yTop += titleH + gap
            }
        } else {
            if !dateTextTrimmed.isEmpty {
                drawTextLine(
                    dateTextTrimmed,
                    font: dateFont,
                    color: textColor,
                    x: xLeft,
                    yTop: yTop,
                    canvasHeight: newH,
                    in: ctx
                )
                yTop += dateH + gap
            }

            for line in titleLinesToDraw {
                drawTextLine(
                    line,
                    font: titleFont,
                    color: textColor,
                    x: xLeft,
                    yTop: yTop,
                    canvasHeight: newH,
                    in: ctx
                )
                yTop += titleH + gap
            }
        }

        guard let outCG = ctx.makeImage() else {
            throw NSError(domain: "FrameMacApp", code: 12, userInfo: [NSLocalizedDescriptionKey: "Could not finalize image"])
        }

        let suffix = "." + srcURL.pathExtension.lowercased()
        let (finalURL, uti, props) = outputSpec(srcURL: srcURL, outDir: outDir, suffix: suffix)

        guard let dest = CGImageDestinationCreateWithURL(finalURL as CFURL, uti as CFString, 1, nil) else {
            throw NSError(domain: "FrameMacApp", code: 13, userInfo: [NSLocalizedDescriptionKey: "Could not create output destination"])
        }

        CGImageDestinationAddImage(dest, outCG, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "FrameMacApp", code: 14, userInfo: [NSLocalizedDescriptionKey: "Could not write output file"])
        }

        return finalURL
    }

    private static func outputSpec(srcURL: URL, outDir: URL, suffix: String) -> (URL, String, [CFString: Any]) {
        if suffix == ".jpg" || suffix == ".jpeg" {
            let out = uniqueOutputURL(
                outDir: outDir,
                baseName: srcURL.deletingPathExtension().lastPathComponent,
                ext: "jpg"
            )
            return (out, UTType.jpeg.identifier, [kCGImageDestinationLossyCompressionQuality: 1.0])
        }

        if suffix == ".tif" || suffix == ".tiff" {
            let out = uniqueOutputURL(
                outDir: outDir,
                baseName: srcURL.deletingPathExtension().lastPathComponent,
                ext: "tif"
            )
            return (out, UTType.tiff.identifier, [kCGImagePropertyTIFFCompression: 5])
        }

        if suffix == ".png" {
            let out = uniqueOutputURL(
                outDir: outDir,
                baseName: srcURL.deletingPathExtension().lastPathComponent,
                ext: "png"
            )
            return (out, UTType.png.identifier, [:])
        }

        let out = uniqueOutputURL(
            outDir: outDir,
            baseName: srcURL.deletingPathExtension().lastPathComponent,
            ext: "jpg"
        )
        return (out, UTType.jpeg.identifier, [kCGImageDestinationLossyCompressionQuality: 1.0])
    }

    private static func uniqueOutputURL(outDir: URL, baseName: String, ext: String) -> URL {
        let fm = FileManager.default
        var candidate = outDir.appendingPathComponent("\(baseName).\(ext)")
        if !fm.fileExists(atPath: candidate.path) {
            return candidate
        }

        var index = 1
        while true {
            candidate = outDir.appendingPathComponent("\(baseName)_\(index).\(ext)")
            if !fm.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private static func loadFont(fileName: String, size: CGFloat, fallbackName: String) -> CTFont {
        if let fontsDir = fontsDirectoryURL() {
            let url = fontsDir.appendingPathComponent(fileName)
            if let provider = CGDataProvider(url: url as CFURL), let cgFont = CGFont(provider) {
                return CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
            }
        }
        return CTFontCreateWithName(fallbackName as CFString, size, nil)
    }

    private static func fontsDirectoryURL() -> URL? {
        let fm = FileManager.default
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("fonts"), fm.fileExists(atPath: bundled.path) {
            return bundled
        }

        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("fonts")
        if fm.fileExists(atPath: cwd.path) {
            return cwd
        }

        let home = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures")
            .appendingPathComponent("Frame")
            .appendingPathComponent("fonts")
        if fm.fileExists(atPath: home.path) {
            return home
        }

        return nil
    }

    private static func lineHeight(_ font: CTFont) -> CGFloat {
        ceil(CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font))
    }

    private static func textWidth(_ text: String, font: CTFont) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font,
        ]
        let attr = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attr)
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    private static func wrapText(_ text: String, font: CTFont, maxWidth: CGFloat) -> [String] {
        if maxWidth <= 0 {
            return text.isEmpty ? [""] : [text]
        }

        let words = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if words.isEmpty {
            return [""]
        }

        func splitLongWord(_ word: String) -> [String] {
            if textWidth(word, font: font) <= maxWidth {
                return [word]
            }
            var parts: [String] = []
            var current = ""
            for ch in word {
                let test = current + String(ch)
                if !current.isEmpty && textWidth(test, font: font) > maxWidth {
                    parts.append(current)
                    current = String(ch)
                } else {
                    current = test
                }
            }
            if !current.isEmpty {
                parts.append(current)
            }
            return parts
        }

        let normalized = words.flatMap(splitLongWord)
        guard let first = normalized.first else {
            return [""]
        }

        var lines: [String] = []
        var line = first

        for w in normalized.dropFirst() {
            let test = line + " " + w
            if textWidth(test, font: font) <= maxWidth {
                line = test
            } else {
                lines.append(line)
                line = w
            }
        }
        lines.append(line)
        return lines
    }

    private static func drawTextLine(
        _ text: String,
        font: CTFont,
        color: CGColor,
        x: CGFloat,
        yTop: Int,
        canvasHeight: Int,
        in ctx: CGContext
    ) {
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font,
            NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): color,
        ]

        let attr = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attr)
        let baselineY = CGFloat(canvasHeight - yTop) - ceil(CTFontGetAscent(font))
        ctx.textPosition = CGPoint(x: x, y: baselineY)
        CTLineDraw(line, ctx)
    }

    private static func imageFiles(in inputDir: URL, invalidInputCode: Int) throws -> [URL] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: inputDir.path, isDirectory: &isDir), isDir.boolValue else {
            throw NSError(
                domain: "FrameMacApp",
                code: invalidInputCode,
                userInfo: [NSLocalizedDescriptionKey: "Input folder not found: \(inputDir.path)"]
            )
        }

        return try fm.contentsOfDirectory(at: inputDir, includingPropertiesForKeys: nil)
            .filter { imageExtensions.contains($0.pathExtension.isEmpty ? "" : "." + $0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }
}

@MainActor
final class FrameViewModel: ObservableObject {
    private static let defaultBorderPixels = "80"
    private static let defaultBottomPixels = "240"
    private static let defaultBorderPercent = "1"
    private static let defaultBottomPercent = "5"
    private static let defaultPadding = "40"
    private static let defaultDateFont = "60"
    private static let defaultTitleFont = "80"
    private static let inputDirKey = "frame.lastInputDir"
    private static let outputDirKey = "frame.lastOutputDir"
    private static let borderModeKey = "frame.borderMode"
    private static let borderPixelsKey = "frame.borderPixels"
    private static let bottomPixelsKey = "frame.bottomPixels"
    private static let borderPercentKey = "frame.borderPercent"
    private static let bottomPercentKey = "frame.bottomPercent"
    private static let titleFontChoiceKey = "frame.titleFontChoice"
    private static let namedSettingsKey = "frame.namedSettings"
    private static let textLayoutKey = "frame.textLayout"

    @Published var inputDir: String
    @Published var outputDir: String

    @Published var borderMode: BorderMode = .pixels {
        didSet {
            syncDisplayedBorderSettings()
            persistPathsAndSettings()
        }
    }
    @Published var border: String = defaultBorderPixels
    @Published var bottom: String = defaultBottomPixels
    @Published var pad: String = defaultPadding
    @Published var dateFont: String = defaultDateFont
    @Published var titleFont: String = defaultTitleFont
    @Published var titleFontChoice: TitleFontChoice = .inter {
        didSet { persistPathsAndSettings() }
    }
    @Published var textLayout: TextLayoutMode = .stacked {
        didSet { persistPathsAndSettings() }
    }
    @Published var presetName: String = ""
    @Published var selectedPresetName: String = ""
    @Published private(set) var presetNames: [String] = []

    @Published var rows: [MetadataRow] = []
    @Published var selectedRows: Set<String> = []
    @Published var status: String = "Ready"
    @Published var progress: Double = 0.0
    @Published var logs: String = ""
    @Published var isScanning = false
    @Published var isRunning = false
    private var namedSettings: [String: SavedSettingPreset] = [:]

    init() {
        let fm = FileManager.default
        let defaults = UserDefaults.standard
        let picturesPath = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures")
            .path
        inputDir = defaults.string(forKey: Self.inputDirKey) ?? picturesPath
        outputDir = defaults.string(forKey: Self.outputDirKey) ?? picturesPath
        if let modeRaw = defaults.string(forKey: Self.borderModeKey),
           let mode = BorderMode(rawValue: modeRaw) {
            borderMode = mode
        }
        if let titleFontChoiceRaw = defaults.string(forKey: Self.titleFontChoiceKey),
           let choice = TitleFontChoice(rawValue: titleFontChoiceRaw) {
            titleFontChoice = choice
        }
        if let textLayoutRaw = defaults.string(forKey: Self.textLayoutKey),
           let saved = TextLayoutMode(rawValue: textLayoutRaw) {
            textLayout = saved
        }

        let savedBorderPx = defaults.string(forKey: Self.borderPixelsKey) ?? Self.defaultBorderPixels
        let savedBottomPx = defaults.string(forKey: Self.bottomPixelsKey) ?? Self.defaultBottomPixels
        let savedBorderPercent = defaults.string(forKey: Self.borderPercentKey) ?? Self.defaultBorderPercent
        let savedBottomPercent = defaults.string(forKey: Self.bottomPercentKey) ?? Self.defaultBottomPercent

        if borderMode == .pixels {
            border = savedBorderPx
            bottom = savedBottomPx
        } else {
            border = savedBorderPercent
            bottom = savedBottomPercent
        }

        loadNamedSettings()
    }

    func chooseInputDir() {
        if let selected = pickDirectory(startingAt: inputDir) {
            inputDir = selected
            persistPathsAndSettings()
            Task { await scanMetadata() }
        }
    }

    func chooseOutputDir() {
        if let selected = pickDirectory(startingAt: outputDir) {
            outputDir = selected
            persistPathsAndSettings()
        }
    }

    func scanMetadata() async {
        guard !isScanning else { return }
        isScanning = true
        status = "Scanning metadata..."
        rows = []
        selectedRows = []

        do {
            let inputPath = inputDir
            let records = try await Task.detached(priority: .userInitiated) {
                try NativeFrameProcessor.scan(inputDir: URL(fileURLWithPath: inputPath))
            }.value
            rows = records.map {
                makeRow(
                    filename: $0.filename,
                    captureDate: $0.captureDate,
                    title: $0.title
                )
            }
            selectedRows = Set(rows.map(\.id))
            status = "Loaded \(rows.count) image(s)"
        } catch {
            status = "Scan failed: \(error.localizedDescription)"
            appendLog("ERROR: \(error.localizedDescription)")
        }

        isScanning = false
    }

    func runProcessing() async {
        guard !isRunning else { return }

        guard !selectedRows.isEmpty else {
            status = "No files selected"
            return
        }

        guard let borderVal = Double(border),
              let bottomVal = Double(bottom),
              let padVal = Int(pad),
              let dateFontVal = Int(dateFont),
              let titleFontVal = Int(titleFont),
              borderVal >= 0, bottomVal >= 0, padVal >= 0, dateFontVal >= 0, titleFontVal >= 0 else {
            status = "Invalid numeric settings"
            return
        }

        persistPathsAndSettings()

        isRunning = true
        progress = 0
        status = "Running..."
        appendLog("Input: \(inputDir)")
        appendLog("Output: \(outputDir)")

        let settings = RenderSettings(
            borderMode: borderMode,
            border: borderVal,
            bottom: bottomVal,
            pad: padVal,
            dateFont: dateFontVal,
            titleFont: titleFontVal,
            titleFontChoice: titleFontChoice,
            textLayout: textLayout
        )

        let selectedFilenames = Set(
            rows
                .filter { selectedRows.contains($0.id) }
                .map(\.filename)
        )

        let overrides = Dictionary(
            uniqueKeysWithValues: rows
                .filter { selectedRows.contains($0.id) }
                .filter(\.isEdited)
                .map { ($0.filename, ($0.captureDate, $0.title)) }
        )

        do {
            let input = URL(fileURLWithPath: inputDir)
            let output = URL(fileURLWithPath: outputDir)
            enum ProcessEvent: Sendable {
                case progress(Int, Int)
                case log(String)
                case done(ProcessSummary)
                case error(String)
            }

            let stream = AsyncStream<ProcessEvent> { continuation in
                Task.detached(priority: .userInitiated) {
                    do {
                        let summary = try NativeFrameProcessor.processFolder(
                            inputDir: input,
                            outputDir: output,
                            settings: settings,
                            metadataOverrides: overrides,
                            includeFilenames: selectedFilenames,
                            progress: { done, total in
                                continuation.yield(.progress(done, total))
                            },
                            log: { line in
                                continuation.yield(.log(line))
                            }
                        )
                        continuation.yield(.done(summary))
                    } catch {
                        continuation.yield(.error(error.localizedDescription))
                    }
                    continuation.finish()
                }
            }

            var summary: ProcessSummary?
            for await event in stream {
                switch event {
                case .progress(let done, let total):
                    if total > 0 {
                        progress = Double(done) / Double(total)
                        status = "Processing \(done)/\(total)"
                    } else {
                        progress = 0
                        status = "No files found"
                    }
                case .log(let line):
                    appendLog(line)
                case .done(let result):
                    summary = result
                case .error(let message):
                    throw NSError(domain: "FrameMacApp", code: 300, userInfo: [NSLocalizedDescriptionKey: message])
                }
            }

            guard let summary else {
                throw NSError(domain: "FrameMacApp", code: 301, userInfo: [NSLocalizedDescriptionKey: "Processing ended without a result."])
            }

            progress = summary.total > 0 ? 1.0 : 0.0
            status = "Done: \(summary.success) ok, \(summary.failed) failed"
        } catch {
            status = "Run failed: \(error.localizedDescription)"
            appendLog("ERROR: \(error.localizedDescription)")
        }

        isRunning = false
    }

    func reverseSelectedEditedFiles() {
        guard !selectedRows.isEmpty else { return }
        rows = rows.map { row in
            if selectedRows.contains(row.id), row.isEdited {
                return makeRow(
                    filename: row.filename,
                    captureDate: row.originalCaptureDate,
                    title: row.originalTitle
                )
            }
            return row
        }
    }

    func resetAll() {
        rows = rows.map {
            makeRow(
                filename: $0.filename,
                captureDate: $0.originalCaptureDate,
                title: $0.originalTitle
            )
        }
        selectedRows = []
    }

    func toggleSelectAll() {
        if selectedRows.count == rows.count && !rows.isEmpty {
            selectedRows = []
        } else {
            selectedRows = Set(rows.map(\.id))
        }
    }

    func isRowSelected(_ row: MetadataRow) -> Bool {
        selectedRows.contains(row.id)
    }

    func setRowSelection(_ row: MetadataRow, isSelected: Bool) {
        if isSelected {
            selectedRows.insert(row.id)
        } else {
            selectedRows.remove(row.id)
        }
    }

    func resetBorderForCurrentMode() {
        switch borderMode {
        case .pixels:
            border = Self.defaultBorderPixels
            bottom = Self.defaultBottomPixels
        case .percent:
            border = Self.defaultBorderPercent
            bottom = Self.defaultBottomPercent
        }
        persistPathsAndSettings()
    }

    func saveLocationPreferences() {
        persistPathsAndSettings()
    }

    func saveCurrentSettingsAsPreset() {
        let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            status = "Preset name is required"
            return
        }

        namedSettings[name] = currentPreset()
        saveNamedSettings()
        presetName = ""
        selectedPresetName = name
        status = "Saved setting: \(name)"
    }

    func loadSelectedPreset() {
        guard !selectedPresetName.isEmpty, let preset = namedSettings[selectedPresetName] else {
            status = "No saved setting selected"
            return
        }

        applyPreset(preset)
        persistPathsAndSettings()
        status = "Loaded setting: \(selectedPresetName)"
    }

    func deleteSelectedPreset() {
        guard !selectedPresetName.isEmpty else {
            status = "No saved setting selected"
            return
        }
        namedSettings.removeValue(forKey: selectedPresetName)
        saveNamedSettings()
        status = "Deleted setting"
    }

    var selectAllButtonTitle: String {
        (selectedRows.count == rows.count && !rows.isEmpty) ? "Deselect All" : "Select All"
    }

    var editedCount: Int {
        rows.filter(\.isEdited).count
    }

    private func appendLog(_ text: String) {
        logs += text + "\n"
    }

    private func makeRow(filename: String, captureDate: String, title: String) -> MetadataRow {
        MetadataRow(
            id: filename,
            filename: filename,
            captureDate: captureDate,
            title: title,
            originalCaptureDate: captureDate,
            originalTitle: title
        )
    }

    private func syncDisplayedBorderSettings() {
        let defaults = UserDefaults.standard
        switch borderMode {
        case .pixels:
            border = defaults.string(forKey: Self.borderPixelsKey) ?? Self.defaultBorderPixels
            bottom = defaults.string(forKey: Self.bottomPixelsKey) ?? Self.defaultBottomPixels
        case .percent:
            border = defaults.string(forKey: Self.borderPercentKey) ?? Self.defaultBorderPercent
            bottom = defaults.string(forKey: Self.bottomPercentKey) ?? Self.defaultBottomPercent
        }
    }

    private func persistPathsAndSettings() {
        let defaults = UserDefaults.standard
        defaults.set(inputDir, forKey: Self.inputDirKey)
        defaults.set(outputDir, forKey: Self.outputDirKey)
        defaults.set(borderMode.rawValue, forKey: Self.borderModeKey)
        defaults.set(titleFontChoice.rawValue, forKey: Self.titleFontChoiceKey)
        defaults.set(textLayout.rawValue, forKey: Self.textLayoutKey)

        if borderMode == .pixels {
            defaults.set(border, forKey: Self.borderPixelsKey)
            defaults.set(bottom, forKey: Self.bottomPixelsKey)
        } else {
            defaults.set(border, forKey: Self.borderPercentKey)
            defaults.set(bottom, forKey: Self.bottomPercentKey)
        }
    }

    private func currentPreset() -> SavedSettingPreset {
        SavedSettingPreset(
            borderMode: borderMode,
            border: border,
            bottom: bottom,
            pad: pad,
            dateFont: dateFont,
            titleFont: titleFont,
            titleFontChoice: titleFontChoice,
            textLayout: textLayout
        )
    }

    private func applyPreset(_ preset: SavedSettingPreset) {
        borderMode = preset.borderMode
        border = preset.border
        bottom = preset.bottom
        pad = preset.pad
        dateFont = preset.dateFont
        titleFont = preset.titleFont
        titleFontChoice = preset.titleFontChoice
        textLayout = preset.textLayout
    }

    private func loadNamedSettings() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Self.namedSettingsKey) else {
            namedSettings = [:]
            presetNames = []
            selectedPresetName = ""
            return
        }

        if let decoded = try? JSONDecoder().decode([String: SavedSettingPreset].self, from: data) {
            namedSettings = decoded
            presetNames = decoded.keys.sorted()
            selectedPresetName = presetNames.first ?? ""
        } else {
            namedSettings = [:]
            presetNames = []
            selectedPresetName = ""
        }
    }

    private func saveNamedSettings() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(namedSettings) {
            defaults.set(data, forKey: Self.namedSettingsKey)
        }
        presetNames = namedSettings.keys.sorted()
        if !selectedPresetName.isEmpty && namedSettings[selectedPresetName] != nil {
            return
        }
        selectedPresetName = presetNames.first ?? ""
    }

    private func pickDirectory(startingAt path: String) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: path)
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}

struct ContentView: View {
    @StateObject private var vm = FrameViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 0.99),
                    Color(red: 0.95, green: 0.96, blue: 0.98),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerSection
                    pathSection
                    settingsSection
                    presetSection
                    filesSection
                    logSection
                }
                .padding(16)
            }
        }
        .onChange(of: vm.inputDir) { _ in
            vm.saveLocationPreferences()
        }
        .onChange(of: vm.outputDir) { _ in
            vm.saveLocationPreferences()
        }
        .task {
            await vm.scanMetadata()
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Frame Studio")
                    .font(.system(size: 27, weight: .semibold))
                Text("Batch frame images with editable metadata and clean typography")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Button("Run Processing") {
                    Task { await vm.runProcessing() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(vm.isRunning || vm.isScanning)

                ProgressView(value: vm.progress)
                    .frame(width: 230)
                Text(vm.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pathSection: some View {
        card("Locations") {
            VStack(spacing: 10) {
                folderRow(
                    label: "Input",
                    text: $vm.inputDir,
                    browseAction: vm.chooseInputDir,
                    trailingButtonTitle: "Load Files",
                    trailingAction: { Task { await vm.scanMetadata() } },
                    trailingDisabled: vm.isScanning || vm.isRunning
                )
                folderRow(
                    label: "Output",
                    text: $vm.outputDir,
                    browseAction: vm.chooseOutputDir,
                    trailingButtonTitle: nil,
                    trailingAction: nil,
                    trailingDisabled: false
                )
            }
        }
    }

    private var settingsSection: some View {
        card("Frame & Typography") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("Border Mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Border Mode", selection: $vm.borderMode) {
                        ForEach(BorderMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    Button("Reset \(vm.borderMode.displayName)") { vm.resetBorderForCurrentMode() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Picker("Text Layout", selection: $vm.textLayout) {
                        ForEach(TextLayoutMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }

                HStack(spacing: 12) {
                    labeledField("Border", text: $vm.border, unit: vm.borderMode.unitLabel)
                    labeledField("Bottom", text: $vm.bottom, unit: vm.borderMode.unitLabel)
                    labeledField("Padding", text: $vm.pad)
                    labeledField("Date Font", text: $vm.dateFont)
                    labeledField("Title Font", text: $vm.titleFont)
                    Spacer()
                    Picker("Title Typeface", selection: $vm.titleFontChoice) {
                        ForEach(TitleFontChoice.allCases) { choice in
                            Text(choice.displayName).tag(choice)
                        }
                    }
                    .frame(width: 220)
                }
            }
        }
    }

    private var presetSection: some View {
        card("Saved Settings") {
            HStack(spacing: 12) {
                TextField("Setting name", text: $vm.presetName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 190)
                Button("Save Current") { vm.saveCurrentSettingsAsPreset() }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Picker("Saved Settings", selection: $vm.selectedPresetName) {
                    Text("Select").tag("")
                    ForEach(vm.presetNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .frame(width: 240)

                Button("Load") { vm.loadSelectedPreset() }
                    .buttonStyle(.bordered)
                    .disabled(vm.selectedPresetName.isEmpty)
                Button("Delete") { vm.deleteSelectedPreset() }
                    .buttonStyle(.bordered)
                    .disabled(vm.selectedPresetName.isEmpty)

                Spacer()
            }
        }
    }

    private var filesSection: some View {
        card("Files") {
            VStack(spacing: 10) {
                HStack {
                    statPill("Images", value: vm.rows.count)
                    statPill("Selected", value: vm.selectedRows.count)
                    statPill("Edited", value: vm.editedCount)
                    Spacer()
                    Button(vm.selectAllButtonTitle) { vm.toggleSelectAll() }
                        .buttonStyle(.bordered)
                        .disabled(vm.rows.isEmpty || vm.isRunning)
                    Button("Reverse Selected Edited") { vm.reverseSelectedEditedFiles() }
                        .buttonStyle(.bordered)
                        .disabled(vm.selectedRows.isEmpty || vm.isRunning)
                    Button("Reset All") { vm.resetAll() }
                        .buttonStyle(.bordered)
                        .disabled(vm.rows.isEmpty || vm.isRunning)
                }

                Table(vm.rows, selection: $vm.selectedRows) {
                    TableColumn("") { row in
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { vm.isRowSelected(row) },
                                set: { vm.setRowSelection(row, isSelected: $0) }
                            )
                        )
                        .labelsHidden()
                    }
                    .width(34)
                    TableColumn("Filename") { row in
                        Text(row.filename)
                    }
                    .width(min: 220, ideal: 320)
                    TableColumn("Capture Date") { row in
                        if let idx = vm.rows.firstIndex(where: { $0.id == row.id }) {
                            TextField("YYYY-MM-DD", text: $vm.rows[idx].captureDate)
                        } else {
                            Text(row.captureDate)
                        }
                    }
                    .width(min: 140, ideal: 170)
                    TableColumn("Title") { row in
                        if let idx = vm.rows.firstIndex(where: { $0.id == row.id }) {
                            TextField("Title", text: $vm.rows[idx].title)
                        } else {
                            Text(row.title)
                        }
                    }
                    .width(min: 340, ideal: 520)
                    TableColumn("Edited") { row in
                        Text(row.isEdited ? "Yes" : "")
                    }
                    .width(70)
                }
                .frame(minHeight: 300)
            }
        }
    }

    private var logSection: some View {
        card("Log") {
            ScrollView {
                Text(vm.logs.isEmpty ? "No logs yet." : vm.logs)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(minHeight: 150)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, unit: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                TextField(label, text: text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 84)
                if let unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func statPill(_ label: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.8))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func folderRow(
        label: String,
        text: Binding<String>,
        browseAction: @escaping () -> Void,
        trailingButtonTitle: String?,
        trailingAction: (() -> Void)?,
        trailingDisabled: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            TextField("\(label) folder", text: text)
                .textFieldStyle(.roundedBorder)
            Button("Browse", action: browseAction)
                .buttonStyle(.bordered)
            if let trailingButtonTitle, let trailingAction {
                Button(trailingButtonTitle, action: trailingAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(trailingDisabled)
            }
        }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

@main
struct FrameMacApp: App {
    var body: some Scene {
        WindowGroup("Frame Mac App") {
            ContentView()
                .frame(minWidth: 980, minHeight: 720)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .saveItem) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .textEditing) {}
            CommandGroup(replacing: .toolbar) {}
            CommandGroup(replacing: .sidebar) {}
            CommandGroup(replacing: .windowList) {}
            CommandGroup(replacing: .help) {}
        }
    }
}
