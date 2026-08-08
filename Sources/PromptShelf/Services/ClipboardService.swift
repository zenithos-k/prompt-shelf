import AppKit

enum ClipboardService {
    @discardableResult
    static func copy(_ value: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(value, forType: .string)
    }
}

enum MenuBarWindowController {
    static func dismiss() {
        DispatchQueue.main.async {
            NSApp.keyWindow?.orderOut(nil)
        }
    }
}
