import SwiftUI

/// NSViewRepresentable that captures key events and forwards them to the triage engine
struct KeyboardHandler: NSViewRepresentable {
    let engine: TriageEngine
    @Binding var isZoomed: Bool
    @Binding var isPlaying: Bool
    @Binding var showHelp: Bool

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyDown = { event in
            handleKey(event)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onKeyDown = { event in
            handleKey(event)
        }
    }

    private func handleKey(_ event: NSEvent) {
        // Dismiss help on any key
        if showHelp {
            showHelp = false
            return
        }

        let chars = event.charactersIgnoringModifiers ?? ""

        switch event.keyCode {
        case 123: // Left arrow
            engine.goToPrevious()
            return
        case 124: // Right arrow
            engine.goToNext()
            return
        case 36: // Enter/Return
            toggleVideoPlayback()
            return
        case 49: // Space
            toggleVideoPlayback()
            return
        default:
            break
        }

        guard let char = chars.first else { return }

        switch char {
        case "h":
            engine.goToPrevious()
        case "l":
            engine.goToNext()
        case "k":
            engine.keepCurrent()
            isPlaying = false
        case "j":
            engine.rejectCurrent()
            isPlaying = false
        case "z":
            engine.undo()
        case "f":
            isZoomed.toggle()
        case "?":
            showHelp.toggle()
        case "1":
            engine.setRating(1)
        case "2":
            engine.setRating(2)
        case "3":
            engine.setRating(3)
        case "4":
            engine.setRating(4)
        case "5":
            engine.setRating(5)
        default:
            break
        }
    }

    private func toggleVideoPlayback() {
        guard let item = engine.currentItem, item.isVideo else { return }
        isPlaying.toggle()
    }
}

/// NSView subclass that becomes first responder and captures key events
class KeyCaptureView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }

    // Suppress the system beep for unhandled keys
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let chars = event.charactersIgnoringModifiers ?? ""
        let handled = "hlkjzf?12345"
        if let char = chars.first, handled.contains(char) {
            return true
        }
        if [36, 49, 123, 124].contains(event.keyCode) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
