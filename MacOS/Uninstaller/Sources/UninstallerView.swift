import SwiftUI

/// The one window: what will go, a button, and then what went.
struct UninstallerView: View {
    let model: UninstallerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Uninstall Photos-Go-Round")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .center)

            switch model.phase {
            case .ready, .working, .stuck:
                found
            case .done where !model.hadTrouble:
                Text("Photos-Go-Round has been removed.")
            case .done:
                Text("Photos-Go-Round was removed, except for what is listed here.")
                outcome
            case .failed(let reason):
                Text("The uninstall stopped: \(reason)")
                outcome
            }

            HStack {
                if model.phase == .working {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                switch model.phase {
                case .ready:
                    Button("Cancel", role: .cancel) { UninstallerDelegate.quit() }
                        .keyboardShortcut(.cancelAction)
                    Button("Uninstall", role: .destructive) { model.uninstall() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!model.hasAnythingToRemove)
                case .working, .stuck:
                    Button("Uninstall") {}.disabled(true)
                case .done, .failed:
                    Button("OK") { UninstallerDelegate.quit() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        // Return is OK's, and Uninstall's before that. **Selection is only on the
        // report**: text made selectable across the whole window took the focus,
        // and with it Return — Syd, 2026-09-27: "enter or return should hit ok."
        .alert(
            "Something did not shut down",
            isPresented: .constant(model.isStuck),
            actions: {
                Button("Force Quit", role: .destructive) { model.forceQuit() }
                Button("Cancel", role: .cancel) { model.cancelForceQuit() }
            },
            message: {
                if case .stuck(let stuck) = model.phase { Text(stuck.explanation) }
            })
    }

    private var found: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(model.items) { item in
                // Dimmed when it is not here, so there is nothing of it to remove.
                Label(item.name, systemImage: item.isPresent ? "checkmark.circle" : "circle.dashed")
                    .foregroundStyle(item.isPresent ? Color.primary : .secondary)
            }
        }
    }

    /// **One block of text, selectable as a whole**, so all of it can be
    /// copied at once — Syd, 2026-09-27: "I need to be able to select and copy
    /// text out of that panel."
    private var outcome: some View {
        ScrollView {
            Text(model.report.joined(separator: "\n"))
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 280)
    }
}
