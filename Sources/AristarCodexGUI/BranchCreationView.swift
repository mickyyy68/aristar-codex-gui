import SwiftUI

struct BranchCreationView: View {
    let branches: [String]
    let onCreate: (String) -> Void
    let errorMessage: String?
    @State private var selectedBranch: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Branch", selection: $selectedBranch) {
                    ForEach(branches, id: \.self) { branch in
                        Text(branch).tag(branch)
                    }
                }
                .pickerStyle(.menu)

                Button("New agent from branch") {
                    guard !selectedBranch.isEmpty else { return }
                    onCreate(selectedBranch)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .textSelection(.enabled)
            }
        }
        .onAppear {
            if selectedBranch.isEmpty {
                selectedBranch = branches.first ?? ""
            }
        }
    }
}
