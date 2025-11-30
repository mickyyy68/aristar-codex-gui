import SwiftUI

struct BranchCreationView: View {
    let branches: [String]
    let onCreate: (String) -> Void
    let errorMessage: String?
    @State private var selectedBranch: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(BrandColor.ion.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .foregroundStyle(BrandColor.ion)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Launch an agent from a branch")
                        .font(BrandFont.display(size: 16, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                    Text("Creates a dedicated worktree so the branch stays isolated while you chat.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Picker(selection: $selectedBranch) {
                    ForEach(branches, id: \.self) { branch in
                        Label(branch, systemImage: "arrow.triangle.branch")
                            .tag(branch)
                    }
                } label: {
                    Label("Base Branch", systemImage: "arrow.triangle.branch")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .brandPanel(cornerRadius: BrandRadius.md)

                Button {
                    guard !selectedBranch.isEmpty else { return }
                    onCreate(selectedBranch)
                } label: {
                    Label("Create Agent", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.brandPrimary)
                .disabled(selectedBranch.isEmpty)
                .opacity(selectedBranch.isEmpty ? 0.6 : 1)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(BrandColor.berry)
                    .textSelection(.enabled)
                    .padding(10)
                    .brandPanel(cornerRadius: BrandRadius.sm)
            }
        }
        .padding(14)
        .brandPanel()
        .brandShadow(.soft)
        .onAppear {
            if selectedBranch.isEmpty {
                selectedBranch = branches.first ?? ""
            }
        }
    }
}
