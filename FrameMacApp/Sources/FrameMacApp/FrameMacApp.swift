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
    let sourcePath: String
    var captureDate: String
    var title: String
    var editorialCaption: String
    var editorialLocation: String
    var editorialAuthor: String
    let originalCaptureDate: String
    let originalTitle: String
    let originalEditorialCaption: String
    let originalEditorialLocation: String
    let originalEditorialAuthor: String

    var isEdited: Bool {
        captureDate != originalCaptureDate ||
        title != originalTitle ||
        editorialCaption != originalEditorialCaption ||
        editorialLocation != originalEditorialLocation ||
        editorialAuthor != originalEditorialAuthor
    }
}

struct FileRenderMetadata: Sendable {
    let captureDate: String
    let title: String
    let editorialCaption: String
    let editorialLocation: String
    let editorialAuthor: String
}

struct RenderSettings: Sendable {
    let frameStyle: FrameStyle
    let borderMode: BorderMode
    let border: Double
    let bottom: Double
    let pad: Int
    let dateFont: Int
    let titleFont: Int
    let titleFontChoice: TitleFontChoice
    let titleFontVariant: TitleFontVariant
    let textLayout: TextLayoutMode
    let editorialSidePercent: Double
    let editorialTopPercent: Double
    let editorialBottomPercent: Double
    let editorialCaption: String
    let editorialLocation: String
    let editorialAuthor: String
}

struct ProcessSummary: Sendable {
    let success: Int
    let total: Int
    var failed: Int { total - success }
}

private struct FontCacheKey: Hashable {
    let fileName: String
    let size: Int
    let fallbackName: String
}

private struct FrameShadowDefinition {
    let offset: CGSize
    let blur: CGFloat
    let color: CGColor
}

private struct FrameStyleDefinition {
    let canvasColor: CGColor
    let textColor: CGColor
    let cornerRadiusFactor: CGFloat
    let imageShadow: FrameShadowDefinition?
    let imageStrokeColor: CGColor?
    let imageStrokeWidth: CGFloat
    let imageOverlayColor: CGColor?
    let imageOverlayBlendMode: CGBlendMode
    let imageRotationDegrees: CGFloat
    let classicBottomScale: Double
}

enum FrameStyle: String, CaseIterable, Identifiable, Sendable, Codable {
    case whiteBorder
    case softShadow
    case roundedCorner
    case vintage
    case polaroid
    case galleryMinimal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whiteBorder:
            return "White Border"
        case .softShadow:
            return "Soft Shadow"
        case .roundedCorner:
            return "Rounded Corner"
        case .vintage:
            return "Vintage"
        case .polaroid:
            return "Polaroid"
        case .galleryMinimal:
            return "Gallery Minimal"
        }
    }

    var description: String {
        switch self {
        case .whiteBorder:
            return "The current clean white frame with straightforward typography."
        case .softShadow:
            return "Adds a soft drop shadow to lift the photo off the canvas."
        case .roundedCorner:
            return "Rounds the image corners while keeping the classic white mat."
        case .vintage:
            return "Warmer paper tones, a subtle sepia wash, and a softer presentation."
        case .polaroid:
            return "A bright instant-film look with a slight tilt and a deeper bottom margin."
        case .galleryMinimal:
            return "Cool off-white canvas with a restrained edge for a modern gallery feel."
        }
    }
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
    let frameStyle: FrameStyle
    let borderMode: BorderMode
    let border: String
    let bottom: String
    let pad: String
    let dateFont: String
    let titleFont: String
    let titleFontChoice: TitleFontChoice
    let titleFontVariant: TitleFontVariant
    let textLayout: TextLayoutMode
    let editorialSidePercent: String
    let editorialTopPercent: String
    let editorialBottomPercent: String
    let editorialCaption: String
    let editorialLocation: String
    let editorialAuthor: String

    init(
        frameStyle: FrameStyle,
        borderMode: BorderMode,
        border: String,
        bottom: String,
        pad: String,
        dateFont: String,
        titleFont: String,
        titleFontChoice: TitleFontChoice,
        titleFontVariant: TitleFontVariant,
        textLayout: TextLayoutMode,
        editorialSidePercent: String,
        editorialTopPercent: String,
        editorialBottomPercent: String,
        editorialCaption: String,
        editorialLocation: String,
        editorialAuthor: String
    ) {
        self.frameStyle = frameStyle
        self.borderMode = borderMode
        self.border = border
        self.bottom = bottom
        self.pad = pad
        self.dateFont = dateFont
        self.titleFont = titleFont
        self.titleFontChoice = titleFontChoice
        self.titleFontVariant = titleFontVariant
        self.textLayout = textLayout
        self.editorialSidePercent = editorialSidePercent
        self.editorialTopPercent = editorialTopPercent
        self.editorialBottomPercent = editorialBottomPercent
        self.editorialCaption = editorialCaption
        self.editorialLocation = editorialLocation
        self.editorialAuthor = editorialAuthor
    }

    private enum CodingKeys: String, CodingKey {
        case frameStyle
        case borderMode
        case border
        case bottom
        case pad
        case dateFont
        case titleFont
        case titleFontChoice
        case titleFontVariant
        case textLayout
        case editorialSidePercent
        case editorialTopPercent
        case editorialBottomPercent
        case editorialCaption
        case editorialLocation
        case editorialAuthor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        frameStyle = try c.decodeIfPresent(FrameStyle.self, forKey: .frameStyle) ?? .whiteBorder
        borderMode = try c.decode(BorderMode.self, forKey: .borderMode)
        border = try c.decode(String.self, forKey: .border)
        bottom = try c.decode(String.self, forKey: .bottom)
        pad = try c.decode(String.self, forKey: .pad)
        dateFont = try c.decode(String.self, forKey: .dateFont)
        titleFont = try c.decode(String.self, forKey: .titleFont)
        titleFontChoice = try c.decode(TitleFontChoice.self, forKey: .titleFontChoice)
        titleFontVariant = try c.decode(TitleFontVariant.self, forKey: .titleFontVariant)
        textLayout = try c.decode(TextLayoutMode.self, forKey: .textLayout)
        editorialSidePercent = try c.decodeIfPresent(String.self, forKey: .editorialSidePercent) ?? "3"
        editorialTopPercent = try c.decodeIfPresent(String.self, forKey: .editorialTopPercent) ?? "1"
        editorialBottomPercent = try c.decodeIfPresent(String.self, forKey: .editorialBottomPercent) ?? "14"
        editorialCaption = try c.decodeIfPresent(String.self, forKey: .editorialCaption) ?? ""
        editorialLocation = try c.decodeIfPresent(String.self, forKey: .editorialLocation) ?? ""
        editorialAuthor = try c.decodeIfPresent(String.self, forKey: .editorialAuthor) ?? ""
    }
}

enum TitleFontVariant: String, CaseIterable, Identifiable, Sendable, Codable {
    case regular
    case semiBold
    case bold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .regular:
            return "Regular"
        case .semiBold:
            return "SemiBold"
        case .bold:
            return "Bold"
        }
    }

    var weightValue: Double {
        switch self {
        case .regular:
            return 400
        case .semiBold:
            return 600
        case .bold:
            return 700
        }
    }
}

enum TextLayoutMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case stacked
    case row
    case editorial

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stacked:
            return "Stacked"
        case .row:
            return "Same Row"
        case .editorial:
            return "Editorial"
        }
    }
}

enum NativeFrameProcessor {
    static let imageExtensions: Set<String> = [".jpg", ".jpeg", ".tif", ".tiff", ".png"]
    static let embeddedXMPHeadBytes = 2_000_000

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

    static func scan(inputDir: URL) async throws -> [MetadataRecord] {
        let files = try listImageFiles(inputDir: inputDir, invalidInputCode: 1)
        return await collectScanRecords(from: scanStream(files: files))
    }

    static func listImageFiles(inputDir: URL, invalidInputCode: Int) throws -> [URL] {
        try imageFiles(in: inputDir, invalidInputCode: invalidInputCode)
    }

    static func scanStream(files: [URL]) -> AsyncStream<[(Int, MetadataRecord)]> {
        guard !files.isEmpty else {
            return AsyncStream { continuation in
                continuation.finish()
            }
        }

        let workerCount = min(max(1, ProcessInfo.processInfo.activeProcessorCount), files.count)
        let chunkSize = max(1, (files.count + workerCount - 1) / workerCount)

        return AsyncStream { continuation in
            Task.detached(priority: .userInitiated) {
                await withTaskGroup(of: [(Int, MetadataRecord)].self) { group in
                    for chunkStart in stride(from: 0, to: files.count, by: chunkSize) {
                        let chunkEnd = min(chunkStart + chunkSize, files.count)
                        let chunk = Array(files[chunkStart..<chunkEnd])

                        group.addTask {
                            var partial: [(Int, MetadataRecord)] = []
                            partial.reserveCapacity(chunk.count)

                            for (offset, url) in chunk.enumerated() {
                                let index = chunkStart + offset
                                partial.append((index, scanRecord(url)))
                            }

                            return partial
                        }
                    }

                    for await partial in group {
                        continuation.yield(partial)
                    }
                    continuation.finish()
                }
            }
        }
    }

    static func processFolder(
        inputDir: URL,
        outputDir: URL,
        settings: RenderSettings,
        metadataByFilename: [String: FileRenderMetadata],
        includeFilenames: Set<String>,
        progress: @escaping (_ done: Int, _ total: Int) -> Void,
        log: @escaping (_ line: String) -> Void
    ) throws -> ProcessSummary {
        let files = try imageFiles(in: inputDir, invalidInputCode: 2).filter { includeFilenames.contains($0.lastPathComponent) }
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let total = files.count
        progress(0, total)

        var success = 0
        var fontCache: [FontCacheKey: CTFont] = [:]
        for (idx, fileURL) in files.enumerated() {
            let filename = fileURL.lastPathComponent
            let metadata = metadataByFilename[filename]
            let dateText = metadata?.captureDate ?? ""
            let titleText = metadata?.title ?? ""
            let editorialCaption = metadata?.editorialCaption ?? settings.editorialCaption
            let editorialLocation = metadata?.editorialLocation ?? settings.editorialLocation
            let editorialAuthor = metadata?.editorialAuthor ?? settings.editorialAuthor

            do {
                let out = try renderAndSave(
                    srcURL: fileURL,
                    outDir: outputDir,
                    dateText: dateText,
                    title: titleText,
                    editorialCaption: editorialCaption,
                    editorialLocation: editorialLocation,
                    editorialAuthor: editorialAuthor,
                    settings: settings,
                    fontCache: &fontCache
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

    static func processFiles(
        files: [URL],
        outputDir: URL,
        settings: RenderSettings,
        metadataByFilePath: [String: FileRenderMetadata],
        progress: @escaping (_ done: Int, _ total: Int) -> Void,
        log: @escaping (_ line: String) -> Void
    ) throws -> ProcessSummary {
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let total = files.count
        progress(0, total)

        var success = 0
        var fontCache: [FontCacheKey: CTFont] = [:]
        for (idx, fileURL) in files.enumerated() {
            let metadata = metadataByFilePath[fileURL.path]
            let dateText = metadata?.captureDate ?? ""
            let titleText = metadata?.title ?? ""
            let editorialCaption = metadata?.editorialCaption ?? settings.editorialCaption
            let editorialLocation = metadata?.editorialLocation ?? settings.editorialLocation
            let editorialAuthor = metadata?.editorialAuthor ?? settings.editorialAuthor

            do {
                let out = try renderAndSave(
                    srcURL: fileURL,
                    outDir: outputDir,
                    dateText: dateText,
                    title: titleText,
                    editorialCaption: editorialCaption,
                    editorialLocation: editorialLocation,
                    editorialAuthor: editorialAuthor,
                    settings: settings,
                    fontCache: &fontCache
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

    static func makePreviewImage(
        srcURL: URL,
        metadata: FileRenderMetadata,
        settings: RenderSettings,
        maxDimension: Int
    ) throws -> NSImage {
        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary

        guard let src = CGImageSourceCreateWithURL(srcURL as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options) else {
            throw NSError(domain: "FrameMacApp", code: 15, userInfo: [NSLocalizedDescriptionKey: "Could not load preview image"])
        }

        var fontCache: [FontCacheKey: CTFont] = [:]
        let outCG = try renderImage(
            cg: cg,
            dateText: metadata.captureDate,
            title: metadata.title,
            editorialCaption: metadata.editorialCaption,
            editorialLocation: metadata.editorialLocation,
            editorialAuthor: metadata.editorialAuthor,
            settings: settings,
            fontCache: &fontCache
        )
        return NSImage(cgImage: outCG, size: NSSize(width: outCG.width, height: outCG.height))
    }

    private static func readCaptureDate(_ url: URL) -> String? {
        guard let props = imageProperties(url) else { return nil }
        return readCaptureDate(from: props)
    }

    private static func scanRecord(_ url: URL) -> MetadataRecord {
        let props = imageProperties(url)
        return MetadataRecord(
            filename: url.lastPathComponent,
            captureDate: props.flatMap(readCaptureDate(from:)) ?? "",
            title: readTitle(url) ?? ""
        )
    }

    private static func collectScanRecords(from stream: AsyncStream<[(Int, MetadataRecord)]>) async -> [MetadataRecord] {
        var indexedRecords: [(Int, MetadataRecord)] = []
        for await partial in stream {
            indexedRecords.append(contentsOf: partial)
        }
        indexedRecords.sort { $0.0 < $1.0 }
        return indexedRecords.map(\.1)
    }

    private static func imageProperties(_ url: URL) -> [CFString: Any]? {
        let options = metadataReadOptions()
        guard let src = CGImageSourceCreateWithURL(url as CFURL, options),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, options) as? [CFString: Any] else {
            return nil
        }
        return props
    }

    private static func metadataReadOptions() -> CFDictionary {
        [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceTypeIdentifierHint: UTType.image.identifier as CFString,
        ] as CFDictionary
    }

    private static func readCaptureDate(from props: [CFString: Any]) -> String? {
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

        // Keep embedded title support, but only scan the front of the file to avoid slow full-file reads.
        if let handle = try? FileHandle(forReadingFrom: url) {
            defer { try? handle.close() }

            if let head = try? handle.read(upToCount: embeddedXMPHeadBytes),
               let title = readXMPTitle(data: head),
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
        editorialCaption: String,
        editorialLocation: String,
        editorialAuthor: String,
        settings: RenderSettings,
        fontCache: inout [FontCacheKey: CTFont]
    ) throws -> URL {
        guard let src = CGImageSourceCreateWithURL(srcURL as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw NSError(domain: "FrameMacApp", code: 10, userInfo: [NSLocalizedDescriptionKey: "Could not load image"])
        }
        let srcProps = CGImageSourceCopyPropertiesAtIndex(src, 0, metadataReadOptions()) as? [CFString: Any]
        let outCG = try renderImage(
            cg: cg,
            dateText: dateText,
            title: title,
            editorialCaption: editorialCaption,
            editorialLocation: editorialLocation,
            editorialAuthor: editorialAuthor,
            settings: settings,
            fontCache: &fontCache
        )
        return try writeOutputImage(outCG: outCG, srcURL: srcURL, outDir: outDir, srcProps: srcProps)
    }

    private static func renderImage(
        cg: CGImage,
        dateText: String,
        title: String,
        editorialCaption: String,
        editorialLocation: String,
        editorialAuthor: String,
        settings: RenderSettings,
        fontCache: inout [FontCacheKey: CTFont]
    ) throws -> CGImage {
        let w = cg.width
        let h = cg.height
        let style = frameStyleDefinition(for: settings.frameStyle, imageWidth: w, imageHeight: h)
        let dateTextTrimmed = dateText.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleTrimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if settings.textLayout == .editorial {
            let sidePercent = min(max(settings.editorialSidePercent, 2.0), 4.0)
            let topPercent = min(max(settings.editorialTopPercent, 0.0), 2.0)
            let bottomPercent = min(max(settings.editorialBottomPercent, 12.0), 16.0)

            let sideBorder = max(0, Int((Double(w) * sidePercent / 100.0).rounded()))
            let topBorder = max(0, Int((Double(h) * topPercent / 100.0).rounded()))
            let bottomBorder = max(0, Int((Double(h) * bottomPercent / 100.0).rounded()))

            let textColor = style.textColor
            let innerPad = max(12, Int((Double(sideBorder) * 0.35).rounded()))
            let xLeft = CGFloat(sideBorder + innerPad)
            let textMaxW = CGFloat(max(1, w - (innerPad * 2)))

            let titleFontBase = loadFont(
                fileName: "SourceSerif4-Regular.ttf",
                size: max(12, Int((Double(bottomBorder) * 0.19).rounded())),
                fallbackName: "TimesNewRomanPSMT",
                cache: &fontCache
            )
            let titleFont = applyFontWeight(titleFontBase, weight: 600)
            let captionFont = loadFont(
                fileName: "SourceSerif4-Regular.ttf",
                size: max(11, Int((Double(bottomBorder) * 0.11).rounded())),
                fallbackName: "TimesNewRomanPSMT",
                cache: &fontCache
            )
            let metaFont = applyFontWeight(
                loadFont(
                    fileName: "Inter-Variable.ttf",
                    size: max(10, Int((Double(bottomBorder) * 0.095).rounded())),
                    fallbackName: "HelveticaNeue",
                    cache: &fontCache
                ),
                weight: 400
            )
            let authorFont = applyFontWeight(
                loadFont(
                    fileName: "Inter-Variable.ttf",
                    size: max(10, Int((Double(bottomBorder) * 0.085).rounded())),
                    fallbackName: "HelveticaNeue",
                    cache: &fontCache
                ),
                weight: 300
            )

            let captionText = editorialCaption.trimmingCharacters(in: .whitespacesAndNewlines)
            let locationText = editorialLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            let authorTextRaw = editorialAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
            let authorText: String
            if authorTextRaw.isEmpty {
                authorText = ""
            } else if authorTextRaw.hasPrefix("©") {
                authorText = authorTextRaw
            } else {
                authorText = "© \(authorTextRaw)"
            }

            let locationDateText: String = {
                if !locationText.isEmpty && !dateTextTrimmed.isEmpty {
                    return "\(locationText) — \(dateTextTrimmed)"
                }
                if !locationText.isEmpty {
                    return locationText
                }
                return dateTextTrimmed
            }()

            let titleLines = titleTrimmed.isEmpty ? [] : wrapText(titleTrimmed, font: titleFont, maxWidth: textMaxW)
            let captionLines = captionText.isEmpty ? [] : wrapText(captionText, font: captionFont, maxWidth: textMaxW)
            let titleH = Int(ceil(lineHeight(titleFont)))
            let captionH = Int(ceil(lineHeight(captionFont)))
            let metaH = Int(ceil(lineHeight(metaFont)))
            let authorH = Int(ceil(lineHeight(authorFont)))
            let gapTight = max(4, Int((Double(bottomBorder) * 0.045).rounded()))
            let gapBlock = max(6, Int((Double(bottomBorder) * 0.07).rounded()))

            var contentH = 0
            if !titleLines.isEmpty {
                contentH += titleLines.count * titleH + max(0, titleLines.count - 1) * gapTight
            }
            if !captionLines.isEmpty {
                if contentH > 0 { contentH += gapBlock }
                contentH += captionLines.count * captionH + max(0, captionLines.count - 1) * gapTight
            }
            if !locationDateText.isEmpty {
                if contentH > 0 { contentH += gapBlock }
                contentH += metaH
            }
            if !authorText.isEmpty {
                if contentH > 0 { contentH += gapTight }
                contentH += authorH
            }

            let hasMissingField = titleTrimmed.isEmpty || captionText.isEmpty || locationDateText.isEmpty || authorText.isEmpty
            let verticalInset = max(10, Int((Double(bottomBorder) * 0.12).rounded()))
            let fitBottomBorder = contentH > 0 ? contentH + verticalInset * 2 : verticalInset * 2
            let actualBottomBorder: Int
            if hasMissingField {
                actualBottomBorder = max(0, fitBottomBorder)
            } else {
                actualBottomBorder = max(bottomBorder, fitBottomBorder)
            }

            let newW = w + sideBorder * 2
            let newH = h + topBorder + actualBottomBorder

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

            ctx.setFillColor(style.canvasColor)
            ctx.fill(CGRect(x: 0, y: 0, width: newW, height: newH))
            drawStyledImage(
                cg,
                in: CGRect(x: sideBorder, y: actualBottomBorder, width: w, height: h),
                style: style,
                context: ctx
            )

            let bottomTopY = topBorder + h
            var yTop = bottomTopY + max(0, (actualBottomBorder - contentH) / 2)

            if !titleLines.isEmpty {
                for line in titleLines {
                    drawTextLine(line, font: titleFont, color: textColor, x: xLeft, yTop: yTop, canvasHeight: newH, in: ctx)
                    yTop += titleH + gapTight
                }
                yTop -= gapTight
            }
            if !captionLines.isEmpty {
                if yTop > bottomTopY { yTop += gapBlock }
                for line in captionLines {
                    drawTextLine(line, font: captionFont, color: textColor, x: xLeft, yTop: yTop, canvasHeight: newH, in: ctx)
                    yTop += captionH + gapTight
                }
                yTop -= gapTight
            }
            if !locationDateText.isEmpty {
                if yTop > bottomTopY { yTop += gapBlock }
                drawTextLine(locationDateText, font: metaFont, color: textColor, x: xLeft, yTop: yTop, canvasHeight: newH, in: ctx)
                yTop += metaH
            }
            if !authorText.isEmpty {
                if yTop > bottomTopY { yTop += gapTight }
                drawTextLine(authorText, font: authorFont, color: textColor, x: xLeft, yTop: yTop, canvasHeight: newH, in: ctx)
            }

            guard let outCG = ctx.makeImage() else {
                throw NSError(domain: "FrameMacApp", code: 12, userInfo: [NSLocalizedDescriptionKey: "Could not finalize image"])
            }
            return outCG
        }

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

        var titleFont = loadFont(
            fileName: settings.titleFontChoice.fileName,
            size: max(1, settings.titleFont),
            fallbackName: settings.titleFontChoice.fallbackPostScriptName,
            cache: &fontCache
        )
        titleFont = applyTitleVariant(titleFont, variant: settings.titleFontVariant)
        let dateFont: CTFont
        if settings.textLayout == .row {
            dateFont = titleFont
        } else {
            dateFont = loadFont(
                fileName: "JetBrainsMono-Regular.ttf",
                size: max(1, settings.dateFont),
                fallbackName: "Menlo",
                cache: &fontCache
            )
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

        let actualBottom = classicBottomSpace(baseBottom: bottom, contentHeight: contentH, style: style)

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

        ctx.setFillColor(style.canvasColor)
        ctx.fill(CGRect(x: 0, y: 0, width: newW, height: newH))

        drawStyledImage(
            cg,
            in: CGRect(x: border, y: actualBottom + border, width: w, height: h),
            style: style,
            context: ctx
        )

        let textColor = style.textColor
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

        return outCG
    }

    private static func frameStyleDefinition(for style: FrameStyle, imageWidth: Int, imageHeight: Int) -> FrameStyleDefinition {
        let baseCorner = CGFloat(max(12, Int((Double(min(imageWidth, imageHeight)) * 0.03).rounded())))

        switch style {
        case .whiteBorder:
            return FrameStyleDefinition(
                canvasColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                textColor: CGColor(gray: 0.16, alpha: 1),
                cornerRadiusFactor: 0,
                imageShadow: nil,
                imageStrokeColor: nil,
                imageStrokeWidth: 0,
                imageOverlayColor: nil,
                imageOverlayBlendMode: .normal,
                imageRotationDegrees: 0,
                classicBottomScale: 1
            )
        case .softShadow:
            return FrameStyleDefinition(
                canvasColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                textColor: CGColor(gray: 0.16, alpha: 1),
                cornerRadiusFactor: 0,
                imageShadow: FrameShadowDefinition(
                    offset: CGSize(width: 0, height: -14),
                    blur: 28,
                    color: CGColor(gray: 0, alpha: 0.22)
                ),
                imageStrokeColor: nil,
                imageStrokeWidth: 0,
                imageOverlayColor: nil,
                imageOverlayBlendMode: .normal,
                imageRotationDegrees: 0,
                classicBottomScale: 1
            )
        case .roundedCorner:
            return FrameStyleDefinition(
                canvasColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                textColor: CGColor(gray: 0.16, alpha: 1),
                cornerRadiusFactor: baseCorner,
                imageShadow: nil,
                imageStrokeColor: CGColor(gray: 0.86, alpha: 1),
                imageStrokeWidth: 1,
                imageOverlayColor: nil,
                imageOverlayBlendMode: .normal,
                imageRotationDegrees: 0,
                classicBottomScale: 1
            )
        case .vintage:
            return FrameStyleDefinition(
                canvasColor: CGColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1),
                textColor: CGColor(red: 0.22, green: 0.19, blue: 0.15, alpha: 1),
                cornerRadiusFactor: baseCorner * 0.55,
                imageShadow: FrameShadowDefinition(
                    offset: CGSize(width: 0, height: -8),
                    blur: 18,
                    color: CGColor(gray: 0, alpha: 0.12)
                ),
                imageStrokeColor: CGColor(red: 0.70, green: 0.62, blue: 0.49, alpha: 1),
                imageStrokeWidth: 1.5,
                imageOverlayColor: CGColor(red: 0.74, green: 0.60, blue: 0.40, alpha: 0.16),
                imageOverlayBlendMode: .multiply,
                imageRotationDegrees: 0,
                classicBottomScale: 1.12
            )
        case .polaroid:
            return FrameStyleDefinition(
                canvasColor: CGColor(red: 0.99, green: 0.99, blue: 0.98, alpha: 1),
                textColor: CGColor(gray: 0.18, alpha: 1),
                cornerRadiusFactor: baseCorner * 0.28,
                imageShadow: FrameShadowDefinition(
                    offset: CGSize(width: 0, height: -12),
                    blur: 24,
                    color: CGColor(gray: 0, alpha: 0.18)
                ),
                imageStrokeColor: CGColor(gray: 0.9, alpha: 1),
                imageStrokeWidth: 1,
                imageOverlayColor: nil,
                imageOverlayBlendMode: .normal,
                imageRotationDegrees: -1.8,
                classicBottomScale: 1.5
            )
        case .galleryMinimal:
            return FrameStyleDefinition(
                canvasColor: CGColor(red: 0.972, green: 0.972, blue: 0.968, alpha: 1),
                textColor: CGColor(gray: 0.24, alpha: 1),
                cornerRadiusFactor: 0,
                imageShadow: nil,
                imageStrokeColor: CGColor(gray: 0.78, alpha: 1),
                imageStrokeWidth: 2,
                imageOverlayColor: nil,
                imageOverlayBlendMode: .normal,
                imageRotationDegrees: 0,
                classicBottomScale: 0.78
            )
        }
    }

    private static func classicBottomSpace(baseBottom: Int, contentHeight: Int, style: FrameStyleDefinition) -> Int {
        let scaledBottom = Int((Double(baseBottom) * style.classicBottomScale).rounded())
        return max(contentHeight, scaledBottom)
    }

    private static func drawStyledImage(
        _ cg: CGImage,
        in rect: CGRect,
        style: FrameStyleDefinition,
        context ctx: CGContext
    ) {
        let radius = min(style.cornerRadiusFactor, min(rect.width, rect.height) * 0.5)
        let rotatedRect = CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
        let imagePath = CGPath(
            roundedRect: rotatedRect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )

        ctx.saveGState()
        ctx.translateBy(x: rect.midX, y: rect.midY)

        if style.imageRotationDegrees != 0 {
            ctx.rotate(by: style.imageRotationDegrees * .pi / 180)
        }

        if let shadow = style.imageShadow {
            ctx.saveGState()
            ctx.setShadow(offset: shadow.offset, blur: shadow.blur, color: shadow.color)
            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.addPath(imagePath)
            ctx.fillPath()
            ctx.restoreGState()
        }

        ctx.saveGState()
        ctx.addPath(imagePath)
        ctx.clip()
        ctx.draw(cg, in: rotatedRect)
        if let overlayColor = style.imageOverlayColor {
            ctx.setBlendMode(style.imageOverlayBlendMode)
            ctx.setFillColor(overlayColor)
            ctx.fill(rotatedRect)
            ctx.setBlendMode(.normal)
        }
        ctx.restoreGState()

        if let strokeColor = style.imageStrokeColor, style.imageStrokeWidth > 0 {
            ctx.addPath(imagePath)
            ctx.setStrokeColor(strokeColor)
            ctx.setLineWidth(style.imageStrokeWidth)
            ctx.strokePath()
        }

        ctx.restoreGState()
    }

    private static func writeOutputImage(outCG: CGImage, srcURL: URL, outDir: URL, srcProps: [CFString: Any]?) throws -> URL {
        let suffix = "." + srcURL.pathExtension.lowercased()
        let (finalURL, uti, props) = outputSpec(srcURL: srcURL, outDir: outDir, suffix: suffix)
        let allProps = mergedImageProperties(srcProps: srcProps, outputProps: props)

        guard let dest = CGImageDestinationCreateWithURL(finalURL as CFURL, uti as CFString, 1, nil) else {
            throw NSError(domain: "FrameMacApp", code: 13, userInfo: [NSLocalizedDescriptionKey: "Could not create output destination"])
        }

        CGImageDestinationAddImage(dest, outCG, allProps as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "FrameMacApp", code: 14, userInfo: [NSLocalizedDescriptionKey: "Could not write output file"])
        }
        return finalURL
    }

    private static func mergedImageProperties(srcProps: [CFString: Any]?, outputProps: [CFString: Any]) -> [CFString: Any] {
        var merged: [CFString: Any] = outputProps
        guard let srcProps else {
            return merged
        }

        for (key, value) in srcProps {
            // Dimensions are derived from rendered pixels and should not be copied from source.
            if key == kCGImagePropertyPixelWidth || key == kCGImagePropertyPixelHeight {
                continue
            }
            if merged[key] == nil {
                merged[key] = value
            }
        }
        return merged
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

    private static func loadFont(fileName: String, size: Int, fallbackName: String, cache: inout [FontCacheKey: CTFont]) -> CTFont {
        let key = FontCacheKey(fileName: fileName, size: size, fallbackName: fallbackName)
        if let cached = cache[key] {
            return cached
        }

        let pointSize = CGFloat(size)
        if let fontsDir = fontsDirectoryURL() {
            let url = fontsDir.appendingPathComponent(fileName)
            if let provider = CGDataProvider(url: url as CFURL), let cgFont = CGFont(provider) {
                let font = CTFontCreateWithGraphicsFont(cgFont, pointSize, nil, nil)
                cache[key] = font
                return font
            }
        }
        let fallback = CTFontCreateWithName(fallbackName as CFString, pointSize, nil)
        cache[key] = fallback
        return fallback
    }

    private static func applyTitleVariant(_ font: CTFont, variant: TitleFontVariant) -> CTFont {
        applyFontWeight(font, weight: variant.weightValue)
    }

    private static func applyFontWeight(_ font: CTFont, weight: Double) -> CTFont {
        guard let axes = CTFontCopyVariationAxes(font) as? [[CFString: Any]] else {
            return font
        }

        guard let weightAxis = axes.first(where: {
            (($0[kCTFontVariationAxisIdentifierKey] as? NSNumber)?.intValue) == 2003265652 // 'wght'
        }) else {
            return font
        }

        guard let axisId = weightAxis[kCTFontVariationAxisIdentifierKey] as? NSNumber else {
            return font
        }

        let minValue = (weightAxis[kCTFontVariationAxisMinimumValueKey] as? NSNumber)?.doubleValue ?? 1
        let maxValue = (weightAxis[kCTFontVariationAxisMaximumValueKey] as? NSNumber)?.doubleValue ?? 1000
        let clamped = min(max(weight, minValue), maxValue)
        let descriptor = CTFontCopyFontDescriptor(font)
        let variedDescriptor = CTFontDescriptorCreateCopyWithVariation(descriptor, axisId, CGFloat(clamped))
        return CTFontCreateWithFontDescriptor(variedDescriptor, CTFontGetSize(font), nil)
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
    private static let defaultEditorialSidePercent = "3"
    private static let defaultEditorialTopPercent = "1"
    private static let defaultEditorialBottomPercent = "14"
    private static let defaultEditorialCaption = ""
    private static let defaultEditorialLocation = ""
    private static let defaultEditorialAuthor = ""
    private static let inputDirKey = "frame.lastInputDir"
    private static let outputDirKey = "frame.lastOutputDir"
    private static let autoUseFramedSubfolderKey = "frame.autoUseFramedSubfolder"
    private static let frameStyleKey = "frame.frameStyle"
    private static let borderModeKey = "frame.borderMode"
    private static let borderPixelsKey = "frame.borderPixels"
    private static let bottomPixelsKey = "frame.bottomPixels"
    private static let borderPercentKey = "frame.borderPercent"
    private static let bottomPercentKey = "frame.bottomPercent"
    private static let titleFontChoiceKey = "frame.titleFontChoice"
    private static let titleFontVariantKey = "frame.titleFontVariant"
    private static let namedSettingsKey = "frame.namedSettings"
    private static let recentTitlesKey = "frame.recentTitles"
    private static let textLayoutKey = "frame.textLayout"
    private static let editorialSidePercentKey = "frame.editorialSidePercent"
    private static let editorialTopPercentKey = "frame.editorialTopPercent"
    private static let editorialBottomPercentKey = "frame.editorialBottomPercent"
    private static let editorialCaptionKey = "frame.editorialCaption"
    private static let editorialLocationKey = "frame.editorialLocation"
    private static let editorialAuthorKey = "frame.editorialAuthor"

    @Published var inputDir: String
    @Published var outputDir: String
    @Published var autoUseFramedSubfolder: Bool {
        didSet { persistPathsAndSettings() }
    }

    @Published var frameStyle: FrameStyle = .whiteBorder {
        didSet { persistPathsAndSettings() }
    }
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
    @Published var titleFontVariant: TitleFontVariant = .regular {
        didSet { persistPathsAndSettings() }
    }
    @Published var textLayout: TextLayoutMode = .stacked {
        didSet { persistPathsAndSettings() }
    }
    @Published var editorialSidePercent: String = defaultEditorialSidePercent
    @Published var editorialTopPercent: String = defaultEditorialTopPercent
    @Published var editorialBottomPercent: String = defaultEditorialBottomPercent
    @Published var editorialCaption: String = defaultEditorialCaption
    @Published var editorialLocation: String = defaultEditorialLocation
    @Published var editorialAuthor: String = defaultEditorialAuthor
    @Published var presetName: String = ""
    @Published var selectedPresetName: String = ""
    @Published private(set) var presetNames: [String] = []
    @Published private(set) var recentTitles: [String] = []
    @Published private(set) var selectedInputFiles: [URL] = []
    @Published var isShowingSavePresetSheet = false
    @Published var isShowingManagePresetsSheet = false

    @Published var rows: [MetadataRow] = []
    @Published var selectedRows: Set<String> = []
    @Published var bulkTitle: String = ""
    @Published var previewImage: NSImage?
    @Published var framedPreviewImage: NSImage?
    @Published var previewFilename: String = ""
    @Published var status: String = "Ready"
    @Published var progress: Double = 0.0
    @Published var logs: String = ""
    @Published var isScanning = false
    @Published var isRunning = false
    private var namedSettings: [String: SavedSettingPreset] = [:]
    private var lastCheckboxSelectionRowID: String?
    private var scanSessionID = UUID()
    private var previewedRowID: String?

    init() {
        let fm = FileManager.default
        let defaults = UserDefaults.standard
        let picturesPath = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures")
            .path
        inputDir = defaults.string(forKey: Self.inputDirKey) ?? picturesPath
        outputDir = defaults.string(forKey: Self.outputDirKey) ?? picturesPath
        autoUseFramedSubfolder = defaults.bool(forKey: Self.autoUseFramedSubfolderKey)
        if let frameStyleRaw = defaults.string(forKey: Self.frameStyleKey),
           let savedFrameStyle = FrameStyle(rawValue: frameStyleRaw) {
            frameStyle = savedFrameStyle
        }
        if let modeRaw = defaults.string(forKey: Self.borderModeKey),
           let mode = BorderMode(rawValue: modeRaw) {
            borderMode = mode
        }
        if let titleFontChoiceRaw = defaults.string(forKey: Self.titleFontChoiceKey),
           let choice = TitleFontChoice(rawValue: titleFontChoiceRaw) {
            titleFontChoice = choice
        }
        if let titleFontVariantRaw = defaults.string(forKey: Self.titleFontVariantKey),
           let variant = TitleFontVariant(rawValue: titleFontVariantRaw) {
            titleFontVariant = variant
        }
        if let textLayoutRaw = defaults.string(forKey: Self.textLayoutKey),
           let saved = TextLayoutMode(rawValue: textLayoutRaw) {
            textLayout = saved
        }
        editorialSidePercent = defaults.string(forKey: Self.editorialSidePercentKey) ?? Self.defaultEditorialSidePercent
        editorialTopPercent = defaults.string(forKey: Self.editorialTopPercentKey) ?? Self.defaultEditorialTopPercent
        editorialBottomPercent = defaults.string(forKey: Self.editorialBottomPercentKey) ?? Self.defaultEditorialBottomPercent
        editorialCaption = defaults.string(forKey: Self.editorialCaptionKey) ?? Self.defaultEditorialCaption
        editorialLocation = defaults.string(forKey: Self.editorialLocationKey) ?? Self.defaultEditorialLocation
        editorialAuthor = defaults.string(forKey: Self.editorialAuthorKey) ?? Self.defaultEditorialAuthor

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
        loadRecentTitles()
    }

    func chooseInputDir() {
        if let selected = pickDirectory(startingAt: inputDir) {
            inputDir = selected
            selectedInputFiles = []
            persistPathsAndSettings()
            Task { await scanMetadata() }
        }
    }

    func chooseInputFiles() {
        if let selected = pickImageFiles(startingAt: inputDir), !selected.isEmpty {
            selectedInputFiles = selected
            if let commonParent = commonInputParentDirectory(for: selected) {
                inputDir = commonParent.path
            }
            persistPathsAndSettings()
            Task { await scanMetadata() }
        }
    }

    func clearSelectedInputFiles() {
        guard !selectedInputFiles.isEmpty else { return }
        selectedInputFiles = []
        persistPathsAndSettings()
        Task { await scanMetadata() }
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
        let sessionID = UUID()
        scanSessionID = sessionID
        status = "Loading files..."
        rows = []
        selectedRows = []
        previewImage = nil
        framedPreviewImage = nil
        previewFilename = ""
        previewedRowID = nil
        lastCheckboxSelectionRowID = nil

        do {
            let selectedFiles = selectedInputFiles
            let inputPath = inputDir
            let files = try await Task.detached(priority: .userInitiated) {
                if !selectedFiles.isEmpty {
                    return selectedFiles
                }
                return try NativeFrameProcessor.listImageFiles(inputDir: URL(fileURLWithPath: inputPath), invalidInputCode: 1)
            }.value

            guard scanSessionID == sessionID else { return }

            rows = files.map {
                makeRow(
                    sourcePath: $0.path,
                    filename: $0.lastPathComponent,
                    captureDate: "",
                    title: "",
                    editorialCaption: "",
                    editorialLocation: "",
                    editorialAuthor: ""
                )
            }
            selectedRows = Set(rows.map(\.id))
            status = rows.isEmpty ? "Loaded 0 image(s)" : "Scanning metadata 0/\(rows.count)"

            var scannedCount = 0
            for await partial in NativeFrameProcessor.scanStream(files: files) {
                guard scanSessionID == sessionID else { return }
                for (index, record) in partial {
                    guard rows.indices.contains(index) else { continue }
                    rows[index].captureDate = record.captureDate
                    rows[index].title = record.title
                }
                scannedCount += partial.count
                status = "Scanning metadata \(min(scannedCount, rows.count))/\(rows.count)"
            }

            guard scanSessionID == sessionID else { return }
            status = rows.isEmpty ? "Loaded 0 image(s)" : "Loaded \(rows.count) image(s)"
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
              let editorialSidePercentVal = Double(editorialSidePercent),
              let editorialTopPercentVal = Double(editorialTopPercent),
              let editorialBottomPercentVal = Double(editorialBottomPercent),
              borderVal >= 0, bottomVal >= 0, padVal >= 0, dateFontVal >= 0, titleFontVal >= 0,
              editorialSidePercentVal >= 0, editorialTopPercentVal >= 0, editorialBottomPercentVal >= 0 else {
            status = "Invalid numeric settings"
            return
        }

        persistPathsAndSettings()

        isRunning = true
        progress = 0
        status = "Running..."
        let outputPath = effectiveOutputDirPath()
        if selectedInputFiles.isEmpty {
            appendLog("Input: \(inputDir)")
        } else {
            appendLog("Input files: \(selectedInputFiles.count)")
        }
        appendLog("Output: \(outputPath)")

        let settings = RenderSettings(
            frameStyle: frameStyle,
            borderMode: borderMode,
            border: borderVal,
            bottom: bottomVal,
            pad: padVal,
            dateFont: dateFontVal,
            titleFont: titleFontVal,
            titleFontChoice: titleFontChoice,
            titleFontVariant: titleFontVariant,
            textLayout: textLayout,
            editorialSidePercent: editorialSidePercentVal,
            editorialTopPercent: editorialTopPercentVal,
            editorialBottomPercent: editorialBottomPercentVal,
            editorialCaption: editorialCaption,
            editorialLocation: editorialLocation,
            editorialAuthor: editorialAuthor
        )

        let selectedFiles = rows
            .filter { selectedRows.contains($0.id) }
            .map { URL(fileURLWithPath: $0.sourcePath) }

        let finalMetadata = Dictionary(
            uniqueKeysWithValues: rows
                .filter { selectedRows.contains($0.id) }
                .map {
                    (
                        $0.sourcePath,
                        FileRenderMetadata(
                            captureDate: $0.captureDate,
                            title: $0.title,
                            editorialCaption: $0.editorialCaption,
                            editorialLocation: $0.editorialLocation,
                            editorialAuthor: $0.editorialAuthor
                        )
                    )
                }
        )

        do {
            let output = URL(fileURLWithPath: outputPath)
            enum ProcessEvent: Sendable {
                case progress(Int, Int)
                case log(String)
                case done(ProcessSummary)
                case error(String)
            }

            let stream = AsyncStream<ProcessEvent> { continuation in
                Task.detached(priority: .userInitiated) {
                    do {
                        let summary = try NativeFrameProcessor.processFiles(
                            files: selectedFiles,
                            outputDir: output,
                            settings: settings,
                            metadataByFilePath: finalMetadata,
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
                    sourcePath: row.sourcePath,
                    filename: row.filename,
                    captureDate: row.originalCaptureDate,
                    title: row.originalTitle,
                    editorialCaption: row.originalEditorialCaption,
                    editorialLocation: row.originalEditorialLocation,
                    editorialAuthor: row.originalEditorialAuthor
                )
            }
            return row
        }
        refreshPreview()
    }

    func resetAll() {
        rows = rows.map {
            makeRow(
                sourcePath: $0.sourcePath,
                filename: $0.filename,
                captureDate: $0.originalCaptureDate,
                title: $0.originalTitle,
                editorialCaption: $0.originalEditorialCaption,
                editorialLocation: $0.originalEditorialLocation,
                editorialAuthor: $0.originalEditorialAuthor
            )
        }
        selectedRows = []
        refreshPreview()
        lastCheckboxSelectionRowID = nil
    }

    func syncTitleToSelectedRows() {
        guard !selectedRows.isEmpty else {
            status = "No files selected"
            return
        }
        let syncedTitle = bulkTitle
        rows = rows.map { row in
            guard selectedRows.contains(row.id) else { return row }
            var updated = row
            updated.title = syncedTitle
            return updated
        }
        rememberRecentTitle(syncedTitle)
        status = "Synced title for \(selectedRows.count) file(s)"
        refreshPreview()
    }

    func syncEditorialToSelectedRows() {
        guard !selectedRows.isEmpty else {
            status = "No files selected"
            return
        }

        rows = rows.map { row in
            guard selectedRows.contains(row.id) else { return row }
            var updated = row
            updated.editorialCaption = editorialCaption
            updated.editorialLocation = editorialLocation
            updated.editorialAuthor = editorialAuthor
            return updated
        }
        status = "Applied editorial text to \(selectedRows.count) file(s)"
        refreshPreview()
    }

    func toggleSelectAll() {
        if selectedRows.count == rows.count && !rows.isEmpty {
            selectedRows = []
        } else {
            selectedRows = Set(rows.map(\.id))
        }
        lastCheckboxSelectionRowID = nil
    }

    func isRowSelected(_ row: MetadataRow) -> Bool {
        selectedRows.contains(row.id)
    }

    func setRowSelection(_ row: MetadataRow, isSelected: Bool, extendRange: Bool = false) {
        defer { lastCheckboxSelectionRowID = row.id }

        guard extendRange,
              let anchorID = lastCheckboxSelectionRowID,
              let anchorIndex = rows.firstIndex(where: { $0.id == anchorID }),
              let currentIndex = rows.firstIndex(where: { $0.id == row.id }) else {
            if isSelected {
                selectedRows.insert(row.id)
            } else {
                selectedRows.remove(row.id)
            }
            return
        }

        let start = min(anchorIndex, currentIndex)
        let end = max(anchorIndex, currentIndex)
        let rangeIDs = rows[start...end].map(\.id)
        if isSelected {
            selectedRows.formUnion(rangeIDs)
        } else {
            selectedRows.subtract(rangeIDs)
        }
    }

    func previewRow(_ row: MetadataRow) {
        previewedRowID = row.id
        previewFilename = row.filename
        refreshPreview()
    }

    func refreshPreview() {
        guard let previewedRowID,
              let row = rows.first(where: { $0.id == previewedRowID }) else {
            previewImage = nil
            framedPreviewImage = nil
            previewFilename = ""
            return
        }

        let url = URL(fileURLWithPath: row.sourcePath)
        previewImage = NSImage(contentsOf: url)

        guard let settings = currentRenderSettings() else {
            framedPreviewImage = nil
            return
        }

        let metadata = FileRenderMetadata(
            captureDate: row.captureDate,
            title: row.title,
            editorialCaption: row.editorialCaption,
            editorialLocation: row.editorialLocation,
            editorialAuthor: row.editorialAuthor
        )

        framedPreviewImage = try? NativeFrameProcessor.makePreviewImage(
            srcURL: url,
            metadata: metadata,
            settings: settings,
            maxDimension: 1400
        )
    }

    func refreshPreviewIfShowing(rowID: String) {
        guard previewedRowID == rowID else { return }
        refreshPreview()
    }

    func revertRow(id: String) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        let row = rows[index]
        guard row.isEdited else { return }

        rows[index] = makeRow(
            sourcePath: row.sourcePath,
            filename: row.filename,
            captureDate: row.originalCaptureDate,
            title: row.originalTitle,
            editorialCaption: row.originalEditorialCaption,
            editorialLocation: row.originalEditorialLocation,
            editorialAuthor: row.originalEditorialAuthor
        )
        refreshPreviewIfShowing(rowID: id)
    }

    func commitRowTitle(at index: Int) {
        guard rows.indices.contains(index) else { return }
        rememberRecentTitle(rows[index].title)
    }

    func applyRecentTitle(_ title: String, toRowAt index: Int) {
        guard rows.indices.contains(index) else { return }
        rows[index].title = title
        rememberRecentTitle(title)
        refreshPreviewIfShowing(rowID: rows[index].id)
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

    var effectiveOutputPathDescription: String {
        effectiveOutputDirPath()
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

    func presentSavePresetSheet() {
        isShowingSavePresetSheet = true
    }

    func presentManagePresetsSheet() {
        isShowingManagePresetsSheet = true
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

    var isUsingSelectedFiles: Bool {
        !selectedInputFiles.isEmpty
    }

    var inputSelectionSummary: String {
        guard !selectedInputFiles.isEmpty else {
            return "Using all supported images from the Input folder."
        }
        if selectedInputFiles.count == 1, let first = selectedInputFiles.first {
            return "Using 1 selected file: \(first.lastPathComponent)"
        }
        return "Using \(selectedInputFiles.count) selected files from the browser."
    }

    var areAllRowsSelected: Bool {
        !rows.isEmpty && selectedRows.count == rows.count
    }

    private func appendLog(_ text: String) {
        logs += text + "\n"
    }

    private func makeRow(
        sourcePath: String,
        filename: String,
        captureDate: String,
        title: String,
        editorialCaption: String,
        editorialLocation: String,
        editorialAuthor: String
    ) -> MetadataRow {
        MetadataRow(
            id: sourcePath,
            filename: filename,
            sourcePath: sourcePath,
            captureDate: captureDate,
            title: title,
            editorialCaption: editorialCaption,
            editorialLocation: editorialLocation,
            editorialAuthor: editorialAuthor,
            originalCaptureDate: captureDate,
            originalTitle: title,
            originalEditorialCaption: editorialCaption,
            originalEditorialLocation: editorialLocation,
            originalEditorialAuthor: editorialAuthor
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
        defaults.set(autoUseFramedSubfolder, forKey: Self.autoUseFramedSubfolderKey)
        defaults.set(frameStyle.rawValue, forKey: Self.frameStyleKey)
        defaults.set(borderMode.rawValue, forKey: Self.borderModeKey)
        defaults.set(titleFontChoice.rawValue, forKey: Self.titleFontChoiceKey)
        defaults.set(titleFontVariant.rawValue, forKey: Self.titleFontVariantKey)
        defaults.set(textLayout.rawValue, forKey: Self.textLayoutKey)
        defaults.set(editorialSidePercent, forKey: Self.editorialSidePercentKey)
        defaults.set(editorialTopPercent, forKey: Self.editorialTopPercentKey)
        defaults.set(editorialBottomPercent, forKey: Self.editorialBottomPercentKey)
        defaults.set(editorialCaption, forKey: Self.editorialCaptionKey)
        defaults.set(editorialLocation, forKey: Self.editorialLocationKey)
        defaults.set(editorialAuthor, forKey: Self.editorialAuthorKey)

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
            frameStyle: frameStyle,
            borderMode: borderMode,
            border: border,
            bottom: bottom,
            pad: pad,
            dateFont: dateFont,
            titleFont: titleFont,
            titleFontChoice: titleFontChoice,
            titleFontVariant: titleFontVariant,
            textLayout: textLayout,
            editorialSidePercent: editorialSidePercent,
            editorialTopPercent: editorialTopPercent,
            editorialBottomPercent: editorialBottomPercent,
            editorialCaption: editorialCaption,
            editorialLocation: editorialLocation,
            editorialAuthor: editorialAuthor
        )
    }

    private func currentRenderSettings() -> RenderSettings? {
        guard let borderVal = Double(border),
              let bottomVal = Double(bottom),
              let padVal = Int(pad),
              let dateFontVal = Int(dateFont),
              let titleFontVal = Int(titleFont),
              let editorialSidePercentVal = Double(editorialSidePercent),
              let editorialTopPercentVal = Double(editorialTopPercent),
              let editorialBottomPercentVal = Double(editorialBottomPercent),
              borderVal >= 0, bottomVal >= 0, padVal >= 0, dateFontVal >= 0, titleFontVal >= 0,
              editorialSidePercentVal >= 0, editorialTopPercentVal >= 0, editorialBottomPercentVal >= 0 else {
            return nil
        }

        return RenderSettings(
            frameStyle: frameStyle,
            borderMode: borderMode,
            border: borderVal,
            bottom: bottomVal,
            pad: padVal,
            dateFont: dateFontVal,
            titleFont: titleFontVal,
            titleFontChoice: titleFontChoice,
            titleFontVariant: titleFontVariant,
            textLayout: textLayout,
            editorialSidePercent: editorialSidePercentVal,
            editorialTopPercent: editorialTopPercentVal,
            editorialBottomPercent: editorialBottomPercentVal,
            editorialCaption: editorialCaption,
            editorialLocation: editorialLocation,
            editorialAuthor: editorialAuthor
        )
    }

    private func applyPreset(_ preset: SavedSettingPreset) {
        frameStyle = preset.frameStyle
        borderMode = preset.borderMode
        border = preset.border
        bottom = preset.bottom
        pad = preset.pad
        dateFont = preset.dateFont
        titleFont = preset.titleFont
        titleFontChoice = preset.titleFontChoice
        titleFontVariant = preset.titleFontVariant
        textLayout = preset.textLayout
        editorialSidePercent = preset.editorialSidePercent
        editorialTopPercent = preset.editorialTopPercent
        editorialBottomPercent = preset.editorialBottomPercent
        editorialCaption = preset.editorialCaption
        editorialLocation = preset.editorialLocation
        editorialAuthor = preset.editorialAuthor
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

    private func loadRecentTitles() {
        recentTitles = UserDefaults.standard.stringArray(forKey: Self.recentTitlesKey) ?? []
    }

    private func rememberRecentTitle(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        recentTitles.removeAll { $0 == trimmed }
        recentTitles.insert(trimmed, at: 0)
        if recentTitles.count > 5 {
            recentTitles = Array(recentTitles.prefix(5))
        }
        UserDefaults.standard.set(recentTitles, forKey: Self.recentTitlesKey)
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

    private func pickImageFiles(startingAt path: String) -> [URL]? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.jpeg, .png, .tiff]
        panel.directoryURL = URL(fileURLWithPath: path)
        return panel.runModal() == .OK ? panel.urls : nil
    }

    private func effectiveOutputDirPath() -> String {
        guard autoUseFramedSubfolder else {
            return outputDir
        }

        if let commonParent = commonInputParentDirectory(for: selectedInputFiles) {
            return commonParent
                .appendingPathComponent("Framed", isDirectory: true)
                .path
        }

        if !selectedInputFiles.isEmpty {
            return outputDir
        }

        return URL(fileURLWithPath: inputDir)
            .appendingPathComponent("Framed", isDirectory: true)
            .path
    }

    private func commonInputParentDirectory(for files: [URL]) -> URL? {
        guard let firstParent = files.first?.deletingLastPathComponent() else { return nil }
        let firstParentPath = firstParent.standardizedFileURL.path
        let allShareParent = files.dropFirst().allSatisfy {
            $0.deletingLastPathComponent().standardizedFileURL.path == firstParentPath
        }
        return allShareParent ? firstParent : nil
    }
}

struct ContentView: View {
    @EnvironmentObject private var vm: FrameViewModel
    @State private var previewRowSelection: Set<String> = []

    private var isShiftPressed: Bool {
        NSEvent.modifierFlags.contains(.shift)
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

                    HStack(alignment: .top, spacing: 20) {
                        workspaceSection
                            .frame(width: 340)
                        settingsSection
                    }

                    filesSection
                    logSection
                }
                .padding(24)
                .frame(maxWidth: 1480, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onChange(of: vm.inputDir) { _ in
            vm.saveLocationPreferences()
        }
        .onChange(of: vm.outputDir) { _ in
            vm.saveLocationPreferences()
        }
        .onChange(of: vm.frameStyle) { _ in vm.refreshPreview() }
        .onChange(of: vm.borderMode) { _ in vm.refreshPreview() }
        .onChange(of: vm.border) { _ in vm.refreshPreview() }
        .onChange(of: vm.bottom) { _ in vm.refreshPreview() }
        .onChange(of: vm.pad) { _ in vm.refreshPreview() }
        .onChange(of: vm.dateFont) { _ in vm.refreshPreview() }
        .onChange(of: vm.titleFont) { _ in vm.refreshPreview() }
        .onChange(of: vm.titleFontChoice) { _ in vm.refreshPreview() }
        .onChange(of: vm.titleFontVariant) { _ in vm.refreshPreview() }
        .onChange(of: vm.textLayout) { _ in vm.refreshPreview() }
        .onChange(of: vm.editorialSidePercent) { _ in vm.refreshPreview() }
        .onChange(of: vm.editorialTopPercent) { _ in vm.refreshPreview() }
        .onChange(of: vm.editorialBottomPercent) { _ in vm.refreshPreview() }
        .onChange(of: vm.editorialCaption) { _ in vm.refreshPreview() }
        .onChange(of: vm.editorialLocation) { _ in vm.refreshPreview() }
        .onChange(of: vm.editorialAuthor) { _ in vm.refreshPreview() }
        .task {
            await vm.scanMetadata()
        }
        .sheet(isPresented: $vm.isShowingSavePresetSheet) {
            savePresetSheet
        }
        .sheet(isPresented: $vm.isShowingManagePresetsSheet) {
            managePresetsSheet
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Frame Studio")
                    .font(.largeTitle.weight(.semibold))
                Text("Batch frame images with editable metadata and clean typography.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    infoBadge(title: "Style", value: vm.frameStyle.displayName)
                    infoBadge(title: "Input", value: vm.isUsingSelectedFiles ? "\(vm.selectedInputFiles.count) file(s)" : "Folder mode")
                    infoBadge(title: "Images", value: "\(vm.rows.count)")
                    infoBadge(title: "Selected", value: "\(vm.selectedRows.count)")
                }
            }

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Status")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if vm.isScanning {
                        statusPill("Scanning")
                    } else if vm.isRunning {
                        statusPill("Processing")
                    }
                }
                ProgressView(value: vm.progress)
                    .controlSize(.small)
                Text(vm.status)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(width: 300, alignment: .leading)
            .background(panelFill)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(panelStroke)
        }
    }

    private var workspaceSection: some View {
        panelCard(
            title: "Workspace",
            subtitle: "Choose source photos and where rendered files should go."
        ) {
            VStack(spacing: 14) {
                subpanel(
                    title: "Load Files",
                    subtitle: vm.inputSelectionSummary,
                    icon: "photo.stack"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        labeledValue(title: "Current folder", value: vm.inputDir)

                        VStack(alignment: .leading, spacing: 10) {
                            Button("Browse Files") { vm.chooseInputFiles() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .disabled(vm.isScanning || vm.isRunning)

                            HStack(spacing: 10) {
                                Button("Open Folder") { vm.chooseInputDir() }
                                    .buttonStyle(.bordered)
                                    .disabled(vm.isScanning || vm.isRunning)
                                if vm.isUsingSelectedFiles {
                                    Button("Use Folder Input") { vm.clearSelectedInputFiles() }
                                        .buttonStyle(.bordered)
                                        .disabled(vm.isScanning || vm.isRunning)
                                }
                            }
                        }
                    }
                }

                subpanel(
                    title: "Output Path",
                    subtitle: vm.autoUseFramedSubfolder ? "Exports into a Framed folder near the current source." : "Exports into the selected folder.",
                    icon: "folder.badge.gearshape"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        labeledValue(title: "Destination", value: vm.outputDir)

                        Button("Choose Folder") { vm.chooseOutputDir() }
                            .buttonStyle(.bordered)
                            .disabled(vm.autoUseFramedSubfolder)

                        Toggle("Auto put output in a \"Framed\" folder beside the current source", isOn: $vm.autoUseFramedSubfolder)

                        labeledValue(title: "Active output path", value: vm.effectiveOutputPathDescription, useMonospaced: true)
                    }
                }
            }
        }
    }

    private var settingsSection: some View {
        panelCard(
            title: "Frame Settings",
            subtitle: "Adjust layout, spacing, and typography before rendering."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Frame Style")
                                .font(.headline)
                            Text(vm.frameStyle.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reset \(vm.borderMode.displayName)") { vm.resetBorderForCurrentMode() }
                            .buttonStyle(.bordered)
                    }

                    HStack(alignment: .top, spacing: 16) {
                        settingsToolbarGroup(title: "Frame Style") {
                            Picker("", selection: $vm.frameStyle) {
                                ForEach(FrameStyle.allCases) { style in
                                    Text(style.displayName).tag(style)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }

                        settingsToolbarGroup(title: "Border Mode") {
                            Picker("", selection: $vm.borderMode) {
                                ForEach(BorderMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }

                        settingsToolbarGroup(title: "Text Layout") {
                            Picker("", selection: $vm.textLayout) {
                                ForEach(TextLayoutMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                )

                if vm.textLayout == .editorial {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 16) {
                            subpanel(
                                title: "Editorial Margins",
                                subtitle: "Control the white space around the image area.",
                                icon: "rectangle.inset.filled"
                            ) {
                                HStack(alignment: .top, spacing: 14) {
                                    compactField("Left / Right", text: $vm.editorialSidePercent, unit: "%")
                                    compactField("Top", text: $vm.editorialTopPercent, unit: "%")
                                    compactField("Bottom", text: $vm.editorialBottomPercent, unit: "%")
                                }
                            }
                            .frame(width: 370)

                            subpanel(
                                title: "Output Notes",
                                subtitle: "These values are applied during render.",
                                icon: "info.circle"
                            ) {
                                VStack(alignment: .leading, spacing: 10) {
                                    settingsValueRow(title: "Style", value: vm.frameStyle.displayName)
                                    settingsValueRow(title: "Mode", value: "Editorial")
                                    settingsValueRow(title: "Selection", value: "\(vm.selectedRows.count) file(s)")
                                    settingsValueRow(title: "Apply action", value: "Use “Apply to Selected” below")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        subpanel(
                            title: "Editorial Copy",
                            subtitle: "Prepare the supporting text that appears around the image.",
                            icon: "text.alignleft"
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                wideField("Caption", text: $vm.editorialCaption, placeholder: "Caption sentence explaining the moment")
                                wideField("Location", text: $vm.editorialLocation, placeholder: "Location")
                                wideField("Author", text: $vm.editorialAuthor, placeholder: "Author")

                                HStack(spacing: 8) {
                                    Button("Apply to Selected") { vm.syncEditorialToSelectedRows() }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(vm.selectedRows.isEmpty || vm.isRunning)
                                    Text("Applies these fields to the currently checkbox-selected files.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        subpanel(
                            title: "Frame Dimensions",
                            subtitle: "Configure the canvas around the \(vm.frameStyle.displayName.lowercased()) preset.",
                            icon: "aspectratio"
                        ) {
                            HStack(alignment: .top, spacing: 14) {
                                compactField("Border", text: $vm.border, unit: vm.borderMode.unitLabel)
                                compactField("Bottom", text: $vm.bottom, unit: vm.borderMode.unitLabel)
                                compactField("Padding", text: $vm.pad)
                                compactField("Date Font", text: $vm.dateFont)
                                compactField("Title Font", text: $vm.titleFont)
                            }
                        }

                        HStack(alignment: .top, spacing: 16) {
                            subpanel(
                                title: "Typography",
                                subtitle: "Choose the font family and weight used for the title.",
                                icon: "textformat"
                            ) {
                                HStack(alignment: .top, spacing: 14) {
                                    settingsToolbarGroup(title: "Font") {
                                        Picker("", selection: $vm.titleFontChoice) {
                                            ForEach(TitleFontChoice.allCases) { choice in
                                                Text(choice.displayName).tag(choice)
                                            }
                                        }
                                        .labelsHidden()
                                    }

                                    settingsToolbarGroup(title: "Weight") {
                                        Picker("", selection: $vm.titleFontVariant) {
                                            ForEach(TitleFontVariant.allCases) { variant in
                                                Text(variant.displayName).tag(variant)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .labelsHidden()
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private var savePresetSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save Current Settings")
                .font(.title3.weight(.semibold))
            Text("Store the current controls as a reusable preset.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("e.g. Portrait Soft", text: $vm.presetName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") {
                    vm.isShowingSavePresetSheet = false
                }
                Button("Save") {
                    vm.saveCurrentSettingsAsPreset()
                    if vm.presetName.isEmpty {
                        vm.isShowingSavePresetSheet = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 380)
    }

    private var managePresetsSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manage Saved Settings")
                .font(.title3.weight(.semibold))
            Text("Load or remove a preset without leaving the current workspace.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("Saved Settings", selection: $vm.selectedPresetName) {
                Text("Select").tag("")
                ForEach(vm.presetNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Button("Load") { vm.loadSelectedPreset() }
                    .disabled(vm.selectedPresetName.isEmpty)
                Button("Delete") { vm.deleteSelectedPreset() }
                    .disabled(vm.selectedPresetName.isEmpty)
                Spacer()
                Button("Close") {
                    vm.isShowingManagePresetsSheet = false
                }
            }
        }
        .padding(22)
        .frame(width: 380)
    }

    private var filesSection: some View {
        panelCard(
            title: "Files",
            subtitle: "Review metadata, preview the source, and decide what to process."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    infoBadge(title: "Images", value: "\(vm.rows.count)")
                    infoBadge(title: "Selected", value: "\(vm.selectedRows.count)")
                    infoBadge(title: "Edited", value: "\(vm.editedCount)")
                    Spacer()
                    Button("Reset All") { vm.resetAll() }
                        .buttonStyle(.bordered)
                        .disabled(vm.rows.isEmpty || vm.isRunning)
                    Button("Run Processing") {
                        Task { await vm.runProcessing() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(vm.isRunning || vm.isScanning)
                }

                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        subpanel(
                            title: "Bulk Title",
                            subtitle: "Apply one title to all checkbox-selected files.",
                            icon: "text.badge.plus"
                        ) {
                            HStack(spacing: 8) {
                                TextField("Title for selected files", text: $vm.bulkTitle)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { vm.syncTitleToSelectedRows() }
                                    .contextMenu {
                                        ForEach(vm.recentTitles, id: \.self) { title in
                                            Button(title) { vm.bulkTitle = title }
                                        }
                                    }
                                if !vm.recentTitles.isEmpty {
                                    Menu("Recent") {
                                        ForEach(vm.recentTitles, id: \.self) { title in
                                            Button(title) { vm.bulkTitle = title }
                                        }
                                    }
                                }
                                Button("Apply") { vm.syncTitleToSelectedRows() }
                                    .buttonStyle(.bordered)
                                    .disabled(vm.selectedRows.isEmpty || vm.isRunning)
                            }
                        }

                        VStack(spacing: 0) {
                            filesListHeader

                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(vm.rows.enumerated()), id: \.element.id) { index, row in
                                        fileRow(row, index: index)
                                    }
                                }
                            }
                        }
                        .frame(minHeight: 340)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    previewSection
                        .frame(width: 380, alignment: .topLeading)
                }
            }
        }
    }

    private var previewSection: some View {
        panelCard(
            title: "Preview",
            subtitle: vm.previewFilename.isEmpty ? "Select a row to preview the source image." : vm.previewFilename
        ) {
            VStack(alignment: .leading, spacing: 14) {
                previewImageCard(
                    title: "Framed Preview",
                    image: vm.framedPreviewImage,
                    emptyText: "Select a file to preview the current frame settings."
                )

                previewImageCard(
                    title: "Source",
                    image: vm.previewImage,
                    emptyText: "Source image appears here."
                )
            }
        }
    }

    private var filesListHeader: some View {
        HStack(spacing: 0) {
            Toggle("", isOn: Binding(
                get: { vm.areAllRowsSelected },
                set: { _ in vm.toggleSelectAll() }
            ))
            .labelsHidden()
            .disabled(vm.rows.isEmpty || vm.isRunning)
            .frame(width: 34, alignment: .center)

            headerLabel("Filename", width: 220, alignment: .leading)
            headerLabel("Folder", width: 130, alignment: .leading)
            headerLabel("Capture Date", width: 140, alignment: .leading)
            headerLabel("Title", minWidth: 260, alignment: .leading)
            headerLabel("", width: 42, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
    }

    private func fileRow(_ row: MetadataRow, index: Int) -> some View {
        let isPreviewed = previewRowSelection.contains(row.id)

        return HStack(spacing: 0) {
            Toggle(
                "",
                isOn: Binding(
                    get: { vm.isRowSelected(row) },
                    set: { vm.setRowSelection(row, isSelected: $0, extendRange: isShiftPressed) }
                )
            )
            .labelsHidden()
            .frame(width: 34, alignment: .center)

            Text(row.filename)
                .lineLimit(1)
                .frame(width: 220, alignment: .leading)

            Text(URL(fileURLWithPath: row.sourcePath).deletingLastPathComponent().lastPathComponent)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 130, alignment: .leading)

            TextField("YYYY-MM-DD", text: $vm.rows[index].captureDate)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(width: 140, alignment: .leading)
                .onChange(of: vm.rows[index].captureDate) { _ in
                    vm.refreshPreviewIfShowing(rowID: row.id)
                }

            TextField("Title", text: $vm.rows[index].title)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .leading)
                .onSubmit { vm.commitRowTitle(at: index) }
                .onChange(of: vm.rows[index].title) { _ in
                    vm.refreshPreviewIfShowing(rowID: row.id)
                }
                .contextMenu {
                    ForEach(vm.recentTitles, id: \.self) { title in
                        Button(title) { vm.applyRecentTitle(title, toRowAt: index) }
                    }
                }

            Button {
                vm.revertRow(id: row.id)
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
            .foregroundStyle(row.isEdited ? .primary : .tertiary)
            .disabled(!row.isEdited || vm.isRunning)
            .frame(width: 42, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isPreviewed ? Color.accentColor.opacity(0.10) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            previewRowSelection = [row.id]
            vm.previewRow(row)
        }
    }

    private func previewImageCard(title: String, image: NSImage?, emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 280)
                        .padding(12)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(.secondary)
                        Text(emptyText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 280)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var logSection: some View {
        panelCard(
            title: "Log",
            subtitle: "Processing details and runtime messages."
        ) {
            ScrollView {
                Text(vm.logs.isEmpty ? "No logs yet." : vm.logs)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minHeight: 150)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func panelCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(18)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(panelStroke)
    }

    private func subpanel<Content: View>(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }

    private func controlBlock<Content: View>(
        title: String,
        width: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(width: width, alignment: .leading)
    }

    private func settingsToolbarGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactField(_ label: String, text: Binding<String>, unit: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 86)
                if let unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func wideField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 320, maxWidth: 520)
        }
    }

    private func settingsValueRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }

    private func headerLabel(
        _ title: String,
        width: CGFloat? = nil,
        minWidth: CGFloat? = nil,
        alignment: Alignment
    ) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(minWidth: minWidth, idealWidth: width, maxWidth: width ?? .infinity, alignment: alignment)
    }

    private func labeledValue(title: String, value: String, useMonospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(useMonospaced ? .system(.caption, design: .monospaced) : .subheadline)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    private func infoBadge(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(Capsule())
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
    }

    private var panelFill: some ShapeStyle {
        .regularMaterial
    }

    private var panelStroke: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
    }
}
@main
struct FrameMacApp: App {
    @StateObject private var vm = FrameViewModel()

    var body: some Scene {
        WindowGroup("Frame Mac App") {
            ContentView()
                .environmentObject(vm)
                .frame(minWidth: 980, minHeight: 720)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .saveItem) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .toolbar) {}
            CommandGroup(replacing: .sidebar) {}
            CommandGroup(replacing: .windowList) {}
            CommandGroup(replacing: .help) {}
            CommandMenu("Settings") {
                Button("Save Current Settings…") {
                    vm.presentSavePresetSheet()
                }
                Button("Manage Saved Settings…") {
                    vm.presentManagePresetsSheet()
                }
            }
        }
    }
}
