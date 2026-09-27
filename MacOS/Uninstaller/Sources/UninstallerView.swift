import SwiftUI

/// The one window: what will go, a button, and then what went.
struct UninstallerView: View {
    let model: UninstallerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Uninstall Photos-Go-Round")
                .font(.title2.bold())

            switch model.phase {
            case .ready, .working, .stuck:
                found
            case .done:
                outcome(title: "Photos-Go-Round has been removed.")
            case .failed(let reason):
                outcome(title: "The uninstall stopped: \(reason)")
            }

            HStack {
                if model.phase == .working {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                switch model.phase {
                case .ready:
                    Button("Cancel", role: .cancel) { NSApp.terminate(nil) }
                        .keyboardShortcut(.cancelAction)
                    Button("Uninstall", role: .destructive) { model.uninstall() }
                        .keyboardShortcut(.defaultAction)
                case .working, .stuck:
                    Button("Uninstall") {}.disabled(true)
                case .done, .failed:
                    Button("Quit") { NSApp.terminate(nil) }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("This removes Photos-Go-Round for your account on this Mac:")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(model.items) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: item.isPresent ? "checkmark.circle" : "circle.dashed")
                            .foregroundStyle(item.isPresent ? Color.primary : .secondary)
                        VStack(alignment: .leading) {
                            Text(item.name)
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            Text("Your settings and your choice of albums and folders go too. Your photographs themselves are not touched.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("macOS may ask for your password to remove the wallpaper's saved picture.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func outcome(title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            ScrollView {
                Text(model.report.joined(separator: "\n"))
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
        }
    }
}
