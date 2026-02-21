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
    let id = UUID()
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
    let border: Int
    let bottom: Int
    let pad: Int
    let dateFont: Int
    let titleFont: Int
}

struct ProcessSummary: Sendable {
    let success: Int
    let total: Int
    var failed: Int { total - success }
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
        progress: @escaping (_ done: Int, _ total: Int) -> Void,
        log: @escaping (_ line: String) -> Void
    ) throws -> ProcessSummary {
        let files = try imageFiles(in: inputDir, invalidInputCode: 2)
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

        let border = max(0, settings.border)
        let bottom = max(0, settings.bottom)
        let pad = max(0, settings.pad)

        let dateTextTrimmed = dateText.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleTrimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        let dateFont = loadFont(fileName: "JetBrainsMono-Regular.ttf", size: CGFloat(max(1, settings.dateFont)), fallbackName: "Menlo")
        let titleFont = loadFont(fileName: "CormorantGaramond-Regular.ttf", size: CGFloat(max(1, settings.titleFont)), fallbackName: "TimesNewRomanPSMT")

        let textMaxW = max(1, w - (pad * 2))
        let gap = max(4, Int(Double(max(1, settings.titleFont)) * 0.35))
        let topOffset = max(0, Int(Double(bottom) * 0.18))

        let dateH = Int(ceil(lineHeight(dateFont)))
        let titleH = Int(ceil(lineHeight(titleFont)))
        let titleLines = titleTrimmed.isEmpty ? [] : wrapText(titleTrimmed, font: titleFont, maxWidth: CGFloat(textMaxW))
        let titleBlockH = titleLines.count * titleH + max(0, titleLines.count - 1) * gap

        var contentH = topOffset
        if !dateTextTrimmed.isEmpty {
            contentH += dateH
            if !titleLines.isEmpty {
                contentH += gap
            }
        }
        contentH += titleBlockH
        contentH += max(0, topOffset / 2)

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

        for line in titleLines {
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
            let out = outDir.appendingPathComponent(srcURL.deletingPathExtension().lastPathComponent + ".jpg")
            return (out, UTType.jpeg.identifier, [kCGImageDestinationLossyCompressionQuality: 1.0])
        }

        if suffix == ".tif" || suffix == ".tiff" {
            let out = outDir.appendingPathComponent(srcURL.deletingPathExtension().lastPathComponent + ".tif")
            return (out, UTType.tiff.identifier, [kCGImagePropertyTIFFCompression: 5])
        }

        if suffix == ".png" {
            let out = outDir.appendingPathComponent(srcURL.deletingPathExtension().lastPathComponent + ".png")
            return (out, UTType.png.identifier, [:])
        }

        let out = outDir.appendingPathComponent(srcURL.deletingPathExtension().lastPathComponent + ".jpg")
        return (out, UTType.jpeg.identifier, [kCGImageDestinationLossyCompressionQuality: 1.0])
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
    @Published var inputDir: String
    @Published var outputDir: String

    @Published var border: String = "80"
    @Published var bottom: String = "240"
    @Published var pad: String = "40"
    @Published var dateFont: String = "60"
    @Published var titleFont: String = "80"

    @Published var rows: [MetadataRow] = []
    @Published var selectedRows: Set<UUID> = []
    @Published var status: String = "Ready"
    @Published var progress: Double = 0.0
    @Published var logs: String = ""
    @Published var isScanning = false
    @Published var isRunning = false

    init() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let candidateInput = home + "/Pictures/Frame/photo"
        let candidateOutput = home + "/Pictures/Frame/framed"
        if fm.fileExists(atPath: candidateInput) {
            inputDir = candidateInput
            outputDir = candidateOutput
        } else {
            inputDir = fm.currentDirectoryPath + "/photo"
            outputDir = fm.currentDirectoryPath + "/framed"
        }
    }

    func chooseInputDir() {
        if let selected = pickDirectory(startingAt: inputDir) {
            inputDir = selected
            Task { await scanMetadata() }
        }
    }

    func chooseOutputDir() {
        if let selected = pickDirectory(startingAt: outputDir) {
            outputDir = selected
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
                MetadataRow(
                    filename: $0.filename,
                    captureDate: $0.captureDate,
                    title: $0.title,
                    originalCaptureDate: $0.captureDate,
                    originalTitle: $0.title
                )
            }
            status = "Loaded \(rows.count) image(s)"
        } catch {
            status = "Scan failed: \(error.localizedDescription)"
            appendLog("ERROR: \(error.localizedDescription)")
        }

        isScanning = false
    }

    func runProcessing() async {
        guard !isRunning else { return }

        guard let borderVal = Int(border),
              let bottomVal = Int(bottom),
              let padVal = Int(pad),
              let dateFontVal = Int(dateFont),
              let titleFontVal = Int(titleFont),
              borderVal >= 0, bottomVal >= 0, padVal >= 0, dateFontVal >= 0, titleFontVal >= 0 else {
            status = "Invalid numeric settings"
            return
        }

        isRunning = true
        progress = 0
        status = "Running..."
        appendLog("Input: \(inputDir)")
        appendLog("Output: \(outputDir)")

        let settings = RenderSettings(
            border: borderVal,
            bottom: bottomVal,
            pad: padVal,
            dateFont: dateFontVal,
            titleFont: titleFontVal
        )

        let overrides = Dictionary(
            uniqueKeysWithValues: rows
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

    func resetSelected() {
        guard !selectedRows.isEmpty else { return }
        rows = rows.map { row in
            if selectedRows.contains(row.id) {
                return MetadataRow(
                    filename: row.filename,
                    captureDate: row.originalCaptureDate,
                    title: row.originalTitle,
                    originalCaptureDate: row.originalCaptureDate,
                    originalTitle: row.originalTitle
                )
            }
            return row
        }
    }

    func resetAll() {
        rows = rows.map {
            MetadataRow(
                filename: $0.filename,
                captureDate: $0.originalCaptureDate,
                title: $0.originalTitle,
                originalCaptureDate: $0.originalCaptureDate,
                originalTitle: $0.originalTitle
            )
        }
        selectedRows = []
    }

    var editedCount: Int {
        rows.filter(\.isEdited).count
    }

    private func appendLog(_ text: String) {
        logs += text + "\n"
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Input Folder")
                TextField("Input folder", text: $vm.inputDir)
                Button("Browse") { vm.chooseInputDir() }
                Button("Load List") { Task { await vm.scanMetadata() } }
                    .disabled(vm.isScanning || vm.isRunning)
            }

            HStack {
                Text("Output Folder")
                TextField("Output folder", text: $vm.outputDir)
                Button("Browse") { vm.chooseOutputDir() }
            }

            HStack(spacing: 12) {
                labeledField("Border", text: $vm.border)
                labeledField("Bottom", text: $vm.bottom)
                labeledField("Padding", text: $vm.pad)
                labeledField("Date Font", text: $vm.dateFont)
                labeledField("Title Font", text: $vm.titleFont)
            }

            HStack {
                Button("Run") { Task { await vm.runProcessing() } }
                    .disabled(vm.isRunning || vm.isScanning)
                ProgressView(value: vm.progress)
                    .frame(width: 220)
                Text(vm.status).font(.caption)
                Spacer()
                Text("Images: \(vm.rows.count)")
                Text("Edited: \(vm.editedCount)")
            }

            Table(vm.rows, selection: $vm.selectedRows) {
                TableColumn("Filename") { row in
                    Text(row.filename)
                }
                .width(min: 220, ideal: 280)
                TableColumn("Capture Date") { row in
                    if let idx = vm.rows.firstIndex(where: { $0.id == row.id }) {
                        TextField("YYYY-MM-DD", text: $vm.rows[idx].captureDate)
                    } else {
                        Text(row.captureDate)
                    }
                }
                .width(min: 140, ideal: 160)
                TableColumn("Title") { row in
                    if let idx = vm.rows.firstIndex(where: { $0.id == row.id }) {
                        TextField("Title", text: $vm.rows[idx].title)
                    } else {
                        Text(row.title)
                    }
                }
                .width(min: 280, ideal: 420)
                TableColumn("Edited") { row in
                    Text(row.isEdited ? "Yes" : "")
                }
                .width(60)
            }
            .frame(minHeight: 280)

            HStack {
                Button("Reset Selected") { vm.resetSelected() }
                    .disabled(vm.selectedRows.isEmpty || vm.isRunning)
                Button("Reset All") { vm.resetAll() }
                    .disabled(vm.rows.isEmpty || vm.isRunning)
            }

            Text("Log").font(.headline)
            ScrollView {
                Text(vm.logs.isEmpty ? "No logs yet." : vm.logs)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(NSColor.textBackgroundColor))
            .frame(minHeight: 140)
        }
        .padding(14)
        .task {
            await vm.scanMetadata()
        }
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption)
            TextField(label, text: text)
                .frame(width: 90)
        }
    }
}

@main
struct FrameMacApp: App {
    var body: some Scene {
        WindowGroup("Frame Mac App") {
            ContentView()
                .frame(minWidth: 980, minHeight: 720)
        }
    }
}
