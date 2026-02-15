@preconcurrency import AVFoundation
import Foundation
import WhisperKit

let modelName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "large-v3-turbo"

func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return "[\(formatter.string(from: Date()))]"
}

actor AudioBuffer {
    private var samples: [Float] = []
    private let maxCount: Int

    init(maxCount: Int) {
        self.maxCount = maxCount
    }

    func append(_ newSamples: [Float]) {
        samples.append(contentsOf: newSamples)
        if samples.count > maxCount {
            samples = Array(samples.suffix(maxCount))
        }
    }

    func getAll() -> [Float] {
        return samples
    }

    func rmsDb() -> Float {
        guard !samples.isEmpty else { return -100.0 }
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(samples.count))
        return 20.0 * log10(max(rms, 1e-10))
    }
}

func run() async throws {
    print("WhisperKit リアルタイム書き起こし")
    print("モデル: \(modelName)")
    print("モデルを準備中...")

    let config = WhisperKitConfig(model: modelName, verbose: false, logLevel: .error)
    let whisperKit = try await WhisperKit(config)

    print("モデル準備完了")
    print("録音開始... (Ctrl+C で終了)")
    print("---")

    let audioEngine = AVAudioEngine()
    let inputNode = audioEngine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)

    let targetSampleRate: Double = 16000
    let bufferDuration: TimeInterval = 3.0
    let maxBufferDuration: TimeInterval = 30.0
    let targetFrameCount = Int(targetSampleRate * bufferDuration)
    let maxFrameCount = Int(targetSampleRate * maxBufferDuration)

    let audioBuffer = AudioBuffer(maxCount: maxFrameCount)

    guard let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: targetSampleRate, channels: 1, interleaved: false
    ) else {
        fatalError("オーディオフォーマットの作成に失敗")
    }

    guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
        fatalError("オーディオコンバーターの作成に失敗")
    }

    inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
        let frameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * targetSampleRate / inputFormat.sampleRate
        )
        guard frameCount > 0,
              let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount)
        else { return }

        var error: NSError?
        let inputBuffer = buffer
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }

        if error == nil, let channelData = convertedBuffer.floatChannelData {
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(convertedBuffer.frameLength)))
            Task {
                await audioBuffer.append(samples)
            }
        }
    }

    audioEngine.prepare()
    try audioEngine.start()

    let options = DecodingOptions(
        task: .transcribe,
        language: "ja",
        temperature: 0.0,
        usePrefillPrompt: true,
        skipSpecialTokens: true,
        withoutTimestamps: true
    )

    var lastText = ""

    while true {
        try await Task.sleep(for: .seconds(bufferDuration))

        let currentBuffer = await audioBuffer.getAll()
        let rmsDb = await audioBuffer.rmsDb()

        guard currentBuffer.count >= targetFrameCount else { continue }

        let results = try await whisperKit.transcribe(audioArray: currentBuffer, decodeOptions: options)

        if let result = results.first {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty && text != lastText {
                print("\(timestamp()) (\(String(format: "%+.1f", rmsDb)) dB) \(text)")
                lastText = text
            } else {
                print("\(timestamp()) (\(String(format: "%+.1f", rmsDb)) dB) (無音)")
            }
        }
    }
}

signal(SIGINT) { _ in
    print("\n終了します")
    exit(0)
}

Task {
    do {
        try await run()
    } catch {
        print("エラー: \(error)")
        exit(1)
    }
}

dispatchMain()
