import AVFoundation
import Foundation
import os
import Speech

func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return "[\(formatter.string(from: Date()))]"
}

print("Apple Speech Framework リアルタイム書き起こし")
print("権限を確認中...")

let semaphore = DispatchSemaphore(value: 0)
nonisolated(unsafe) var authorized = false

SFSpeechRecognizer.requestAuthorization { status in
    authorized = (status == .authorized)
    semaphore.signal()
}
semaphore.wait()

guard authorized else {
    print("エラー: 音声認識の権限が許可されていません")
    print("システム設定 > プライバシーとセキュリティ > 音声認識 で許可してください")
    exit(1)
}

guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP")) else {
    print("エラー: 日本語の音声認識が利用できません")
    exit(1)
}

guard recognizer.isAvailable else {
    print("エラー: 音声認識サービスが利用できません")
    exit(1)
}

print("録音開始... (Ctrl+C で終了)")
print("---")

let audioEngine = AVAudioEngine()
let request = SFSpeechAudioBufferRecognitionRequest()
request.shouldReportPartialResults = true

let inputNode = audioEngine.inputNode
let recordingFormat = inputNode.outputFormat(forBus: 0)

let rmsDbLock = OSAllocatedUnfairLock(initialState: Float(-100.0))

inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
    request.append(buffer)
    if let channelData = buffer.floatChannelData {
        let count = Int(buffer.frameLength)
        let samples = UnsafeBufferPointer(start: channelData[0], count: count)
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(max(count, 1)))
        let db = 20.0 * log10(max(rms, 1e-10))
        rmsDbLock.withLock { $0 = db }
    }
}

audioEngine.prepare()
do {
    try audioEngine.start()
} catch {
    print("エラー: オーディオエンジンの開始に失敗: \(error)")
    exit(1)
}

nonisolated(unsafe) var lastFinalText = ""
nonisolated(unsafe) var currentPartialText = ""

let task = recognizer.recognitionTask(with: request) { result, error in
    if let error = error {
        print("\nエラー: \(error.localizedDescription)")
        return
    }

    guard let result = result else { return }

    let text = result.bestTranscription.formattedString

    let dbStr = String(format: "%+.1f", rmsDbLock.withLock { $0 })

    if result.isFinal {
        if !text.isEmpty {
            let clearLine = "\r" + String(repeating: " ", count: currentPartialText.count + 20) + "\r"
            print(clearLine, terminator: "")
            print("\(timestamp()) (\(dbStr) dB) \(text)")
            lastFinalText = text
            currentPartialText = ""
        }
    } else {
        if text != lastFinalText && !text.isEmpty {
            let displayText = "\(timestamp()) (\(dbStr) dB) \(text)"
            currentPartialText = displayText
            print("\r\(displayText)", terminator: "")
            fflush(stdout)
        }
    }
}

signal(SIGINT) { _ in
    print("\n終了します")
    exit(0)
}

dispatchMain()
