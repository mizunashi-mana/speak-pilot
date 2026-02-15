import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("VoiceInput")
                .font(.headline)

            Text("音声入力は準備中です")
                .foregroundStyle(.secondary)

            Divider()

            Button("終了") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 200)
    }
}
