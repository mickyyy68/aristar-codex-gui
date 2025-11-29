import SwiftUI
import AppKit

struct FolderPickerButton: View {
    var onPicked: (URL) -> Void

    var body: some View {
        Button {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.begin { response in
                if response == .OK, let url = panel.urls.first {
                    onPicked(url)
                }
            }
        } label: {
            Label("Open Project Folder…", systemImage: "folder")
                .font(BrandFont.ui(size: 14, weight: .semibold))
                .foregroundColor(BrandColor.flour)
        }
    }
}
