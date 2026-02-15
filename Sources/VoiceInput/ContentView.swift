import SwiftUI

struct ContentView: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            statusSection
            transcriptionSection
            controlSection
            Divider()
            footerSection
        }
        .padding()
        .frame(width: 260)
        .task {
            await appState.setup()
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusSection: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.headline)
            Spacer()
        }
    }

    private var statusText: String {
        switch appState.state {
        case .idle:
            "停止中"
        case .starting:
            "起動中..."
        case .ready:
            "待機中"
        case .listening:
            "録音中"
        case .error:
            "エラー"
        }
    }

    private var statusColor: Color {
        switch appState.state {
        case .idle:
            .gray
        case .starting:
            .orange
        case .ready:
            .green
        case .listening:
            .red
        case .error:
            .red
        }
    }

    // MARK: - Transcription

    @ViewBuilder
    private var transcriptionSection: some View {
        if appState.state == .listening || !appState.currentTranscription.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentTranscription.isEmpty ? "..." : appState.currentTranscription)
                    .font(.body)
                    .foregroundStyle(appState.currentTranscription.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(5)
            }
            .padding(8)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlSection: some View {
        switch appState.state {
        case .idle:
            EmptyView()

        case .starting:
            ProgressView()
                .controlSize(.small)

        case .ready:
            Button("録音開始") {
                appState.toggleListening()
            }

        case .listening:
            Button("録音停止") {
                appState.toggleListening()
            }

        case .error(let message):
            VStack(spacing: 8) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)

                Button("再試行") {
                    Task {
                        await appState.setup()
                    }
                }
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerSection: some View {
        HStack {
            if !appState.isAccessibilityGranted {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .help("Accessibility 権限が未許可です")
            }

            Text("⌃⌥Space でトグル")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("終了") {
                Task {
                    await appState.shutdown()
                    NSApplication.shared.terminate(nil)
                }
            }
            .controlSize(.small)
        }
    }
}
