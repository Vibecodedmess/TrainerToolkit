import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import BackupFormat

/// A backup as a file for the Files "Save" sheet.
struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Back up to iCloud Drive (or anywhere in Files), automatic daily backups, and restore.
struct BackupView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(BackupManager.autoEnabledKey) private var autoEnabled = false

    private enum ImportMode { case folder, restore }

    @State private var exportFile: BackupFile?
    @State private var exportName = "TrainerToolkit-backup.json"
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importMode: ImportMode = .restore
    @State private var pendingRestore: AppBackup?
    @State private var confirmUndo = false
    @State private var message: String?
    @State private var isError = false
    /// Bumped after changes that live in UserDefaults, so the screen re-reads them.
    @State private var refresh = 0

    var body: some View {
        Form {
            statusSection
            Section {
                Button {
                    exportNow()
                } label: {
                    Label("Back up now…", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("Saves one backup file where you choose in Files, for example in iCloud Drive.")
            }
            // Kept on its own section: some iOS versions only honour one file sheet per view.
            .fileExporter(isPresented: $showExporter, document: exportFile, contentType: .json, defaultFilename: exportName) { result in
                switch result {
                case .success:
                    BackupManager.markBackedUp()
                    show("Backup saved.")
                case .failure(let error):
                    show(error.localizedDescription, error: true)
                }
                refresh += 1
            }
            folderSection
            restoreSection
        }
        .id(refresh)
        .navigationTitle("Backup")
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: importMode == .folder ? [.folder] : [.json]) { result in
            handleImport(result)
        }
        .confirmationDialog("Replace all data with this backup?", isPresented: Binding(
            get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                            titleVisibility: .visible, presenting: pendingRestore) { backup in
            Button("Replace all data", role: .destructive) { restore(backup) }
        } message: { backup in
            Text(summaryText(backup))
        }
        .confirmationDialog("Undo the last restore?", isPresented: $confirmUndo, titleVisibility: .visible) {
            Button("Put back the data from before the restore", role: .destructive) { undoRestore() }
        } message: {
            Text("The data from before your last restore comes back. What's in the app now becomes the new undo copy.")
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section {
            LabeledContent("Last backup") {
                if let date = BackupManager.lastBackup {
                    Text(date, format: .relative(presentation: .named))
                } else {
                    Text("Never").foregroundStyle(.orange)
                }
            }
            if let message {
                Label(message, systemImage: isError ? "exclamationmark.triangle" : "checkmark.circle")
                    .foregroundStyle(isError ? .orange : .green)
            }
        } footer: {
            Text("A sideloaded app has to be re-signed every 7 days. Reinstalling over it keeps your data, but deleting the app doesn't. A backup in iCloud Drive keeps your collection, goals, event plans, searches and trade lists safe.")
        }
    }

    private var folderSection: some View {
        Section {
            if BackupManager.hasFolder {
                LabeledContent("Folder", value: BackupManager.folderName ?? "Chosen folder")
                Toggle("Back up automatically", isOn: $autoEnabled)
                Button {
                    backUpToFolder()
                } label: {
                    Label("Back up to this folder now", systemImage: "arrow.up.doc")
                }
                Button("Choose another folder…") { pick(.folder) }
                Button("Stop using this folder", role: .destructive) {
                    BackupManager.clearFolder()
                    autoEnabled = false
                    refresh += 1
                }
                if let error = BackupManager.lastAutoError {
                    Label("Last automatic backup failed: \(error)", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } else {
                Button {
                    pick(.folder)
                } label: {
                    Label("Choose a folder…", systemImage: "folder.badge.plus")
                }
            }
        } header: {
            Text("Automatic backups")
        } footer: {
            Text("Pick a folder in iCloud Drive (in the picker: Browse > iCloud Drive, then create a folder such as \"Trainer Toolkit\"). When the app opens and the last automatic backup is more than a day old, a dated backup is written there. The newest \(BackupManager.keepCount) are kept.")
        }
    }

    private var restoreSection: some View {
        Section {
            Button {
                pick(.restore)
            } label: {
                Label("Restore from a backup file…", systemImage: "arrow.down.doc")
            }
            if BackupManager.undoAvailable {
                Button("Undo the last restore", role: .destructive) { confirmUndo = true }
            }
        } header: {
            Text("Restore")
        } footer: {
            Text("Replaces everything in the app with the backup, after showing what's in it. Your current data is kept inside the app first, so the restore can be undone.")
        }
    }

    // MARK: - Actions

    private func pick(_ mode: ImportMode) {
        importMode = mode
        showImporter = true
    }

    private func show(_ text: String, error: Bool = false) {
        message = text
        isError = error
    }

    private func exportNow() {
        do {
            exportFile = BackupFile(data: try BackupManager.snapshot(modelContext).encoded())
            exportName = AppBackup.fileName(for: .now)
            showExporter = true
        } catch {
            show(error.localizedDescription, error: true)
        }
    }

    private func backUpToFolder() {
        do {
            let name = try BackupManager.backUpToFolder(modelContext)
            show("Saved \(name).")
        } catch {
            show(error.localizedDescription, error: true)
        }
        refresh += 1
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            show(error.localizedDescription, error: true)
        case .success(let url):
            switch importMode {
            case .folder:
                do {
                    try BackupManager.setFolder(url)
                    autoEnabled = true
                    backUpToFolder()
                } catch {
                    show(error.localizedDescription, error: true)
                }
            case .restore:
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                do {
                    let backup = try AppBackup.decode(try Data(contentsOf: url))
                    if backup.isEmpty {
                        show("That backup is empty.", error: true)
                    } else {
                        pendingRestore = backup
                    }
                } catch {
                    show(error.localizedDescription, error: true)
                }
            }
        }
        refresh += 1
    }

    private func restore(_ backup: AppBackup) {
        do {
            try BackupManager.restore(backup, into: modelContext)
            show("Restored the backup from \(backup.createdAt.formatted(date: .abbreviated, time: .shortened)).")
        } catch {
            show(error.localizedDescription, error: true)
        }
        pendingRestore = nil
        refresh += 1
    }

    private func undoRestore() {
        do {
            try BackupManager.undoLastRestore(into: modelContext)
            show("Put back the data from before the last restore.")
        } catch {
            show(error.localizedDescription, error: true)
        }
        refresh += 1
    }

    private func summaryText(_ backup: AppBackup) -> String {
        let parts = backup.summary.filter { $0.count > 0 }.map { "\($0.label): \($0.count)" }
        let made = backup.createdAt.formatted(date: .abbreviated, time: .shortened)
        return "Backup from \(made): " + (parts.isEmpty ? "only settings" : parts.joined(separator: ", "))
            + ". Everything currently in the app is replaced."
    }
}
