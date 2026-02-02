import SwiftUI
import AppKit

@main
struct SiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force the app to the foreground — needed when launched from CLI without a .app bundle
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

struct RootView: View {
    @State private var engine: TriageEngine?
    @State private var showFolderPicker = false

    var body: some View {
        Group {
            if let engine = engine {
                ContentView(engine: engine)
                    .task {
                        await engine.startScan()
                    }
            } else {
                folderPickerView
            }
        }
        .onAppear {
            resolveFolder()
        }
    }

    private var folderPickerView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Sift")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Photo & Video Triage")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button("Open Folder...") {
                pickFolder()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)))
    }

    private func resolveFolder() {
        // Check CLI arguments
        let args = CommandLine.arguments
        if args.count > 1 {
            let path = args[1]
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                engine = TriageEngine(rootURL: url)
                return
            }
        }
        // No valid argument, will show folder picker
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder of photos and videos to triage"
        panel.prompt = "Open"

        if panel.runModal() == .OK, let url = panel.url {
            engine = TriageEngine(rootURL: url)
        }
    }
}
