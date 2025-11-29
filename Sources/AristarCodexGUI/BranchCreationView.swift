import SwiftUI

struct BranchCreationView: View {
    let branches: [String]
    let onCreate: (String) -> Void
    let errorMessage: String?
    @State private var selectedBranch: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Launch an agent from a branch")
                        .font(.headline)
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

                Button {
                    guard !selectedBranch.isEmpty else { return }
                    onCreate(selectedBranch)
                } label: {
                    Label("Create Agent", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedBranch.isEmpty)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
        )
        .onAppear {
            if selectedBranch.isEmpty {
                selectedBranch = branches.first ?? ""
            }
        }
    }
}
