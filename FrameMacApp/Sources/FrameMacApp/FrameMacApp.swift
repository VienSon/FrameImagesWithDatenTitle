import AppKit
import Foundation
import SwiftUI

struct ScanImage: Decodable {
    let filename: String
    let capture_date: String
    let title: String
}

struct BackendEvent: Decodable {
    let event: String
    let message: String?
    let done: Int?
    let total: Int?
    let success: Int?
    let failed: Int?
    let images: [ScanImage]?
    let count: Int?
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

enum BackendRunner {
    static func run(
        backendPath: String,
        args: [String],
        onEvent: @escaping @MainActor (BackendEvent) -> Void
    ) async throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: backendPath)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()

        do {
            for try await line in pipe.fileHandleForReading.bytes.lines {
                guard !line.isEmpty else { continue }
                if let data = line.data(using: .utf8),
                   let event = try? JSONDecoder().decode(BackendEvent.self, from: data) {
                    await onEvent(event)
                }
            }
        } catch {
            // Ignore stream-iteration errors and rely on process exit status.
        }

        process.waitUntilExit()
        return process.terminationStatus
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
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidateInput = home + "/Pictures/Frame/photo"
        let candidateOutput = home + "/Pictures/Frame/framed"
        if FileManager.default.fileExists(atPath: candidateInput) {
            self.inputDir = candidateInput
            self.outputDir = candidateOutput
        } else {
            self.inputDir = FileManager.default.currentDirectoryPath + "/photo"
            self.outputDir = FileManager.default.currentDirectoryPath + "/framed"
        }
    }

    private var backendPath: String {
        if let env = ProcessInfo.processInfo.environment["FRAME_BACKEND_PATH"],
           !env.isEmpty {
            return env
        }
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("frame-backend").path {
            return bundled
        }
        return FileManager.default.currentDirectoryPath + "/frame-backend"
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
        if !FileManager.default.fileExists(atPath: backendPath) {
            status = "Missing backend script: frame-backend"
            return
        }

        isScanning = true
        status = "Scanning metadata..."
        rows = []
        selectedRows = []

        do {
            let exitCode = try await BackendRunner.run(
                backendPath: backendPath,
                args: ["scan", "--input", inputDir]
            ) { [weak self] event in
                guard let self else { return }
                if event.event == "scan_result" {
                    let images = event.images ?? []
                    self.rows = images.map {
                        MetadataRow(
                            filename: $0.filename,
                            captureDate: $0.capture_date,
                            title: $0.title,
                            originalCaptureDate: $0.capture_date,
                            originalTitle: $0.title
                        )
                    }
                    self.status = "Loaded \(self.rows.count) image(s)"
                } else if event.event == "error" {
                    self.status = event.message ?? "Scan failed"
                    self.appendLog("ERROR: \(event.message ?? "Scan failed")")
                }
            }
            if exitCode != 0 && status == "Scanning metadata..." {
                status = "Scan exited with code \(exitCode)"
            }
        } catch {
            status = "Scan failed: \(error.localizedDescription)"
            appendLog("ERROR: \(error.localizedDescription)")
        }

        isScanning = false
    }

    func runProcessing() async {
        guard !isRunning else { return }
        guard FileManager.default.fileExists(atPath: backendPath) else {
            status = "Missing backend script: frame-backend"
            return
        }

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
        progress = 0.0
        status = "Running..."
        appendLog("Input: \(inputDir)")
        appendLog("Output: \(outputDir)")

        let editedOverrides = Dictionary(
            uniqueKeysWithValues: rows
                .filter(\.isEdited)
                .map { ($0.filename, ["capture_date": $0.captureDate, "title": $0.title]) }
        )

        var tempOverridePath: String?
        if !editedOverrides.isEmpty {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("frame-overrides-\(UUID().uuidString).json")
            let data = try? JSONSerialization.data(withJSONObject: editedOverrides, options: [.prettyPrinted])
            if let data {
                try? data.write(to: tempURL)
                tempOverridePath = tempURL.path
            }
        }

        var args = [
            "run",
            "--input", inputDir,
            "--output", outputDir,
            "--border", String(borderVal),
            "--bottom", String(bottomVal),
            "--pad", String(padVal),
            "--date-font", String(dateFontVal),
            "--title-font", String(titleFontVal),
        ]
        if let tempOverridePath {
            args += ["--overrides-json", tempOverridePath]
        }

        do {
            let exitCode = try await BackendRunner.run(backendPath: backendPath, args: args) { [weak self] event in
                guard let self else { return }
                switch event.event {
                case "progress":
                    let done = event.done ?? 0
                    let total = event.total ?? 0
                    if total > 0 {
                        self.progress = Double(done) / Double(total)
                        self.status = "Processing \(done)/\(total)"
                    }
                case "log":
                    self.appendLog(event.message ?? "")
                case "done":
                    let success = event.success ?? 0
                    let failed = event.failed ?? 0
                    self.progress = 1.0
                    self.status = "Done: \(success) ok, \(failed) failed"
                    self.appendLog("Done: \(success) ok, \(failed) failed")
                case "error":
                    self.status = event.message ?? "Run failed"
                    self.appendLog("ERROR: \(event.message ?? "Run failed")")
                default:
                    break
                }
            }
            if exitCode != 0 && !status.starts(with: "Done:") {
                status = "Run exited with code \(exitCode)"
            }
        } catch {
            status = "Run failed: \(error.localizedDescription)"
            appendLog("ERROR: \(error.localizedDescription)")
        }

        if let tempOverridePath {
            try? FileManager.default.removeItem(atPath: tempOverridePath)
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
