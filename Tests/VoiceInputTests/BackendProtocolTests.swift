import Foundation
import Testing

@testable import VoiceInput

// MARK: - BackendCommand Encoding

@Suite("BackendCommand encoding")
struct BackendCommandTests {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    @Test func encodeStart() throws {
        let json = try String(data: encoder.encode(BackendCommand.start), encoding: .utf8)
        #expect(json == #"{"type":"start"}"#)
    }

    @Test func encodeStop() throws {
        let json = try String(data: encoder.encode(BackendCommand.stop), encoding: .utf8)
        #expect(json == #"{"type":"stop"}"#)
    }

    @Test func encodeShutdown() throws {
        let json = try String(data: encoder.encode(BackendCommand.shutdown), encoding: .utf8)
        #expect(json == #"{"type":"shutdown"}"#)
    }
}

// MARK: - BackendEvent Decoding

@Suite("BackendEvent decoding")
struct BackendEventTests {
    private let decoder = JSONDecoder()

    @Test func decodeReady() throws {
        let data = Data(#"{"type":"ready"}"#.utf8)
        let event = try decoder.decode(BackendEvent.self, from: data)
        #expect(event == .ready)
    }

    @Test func decodeSpeechStarted() throws {
        let data = Data(#"{"type":"speech_started"}"#.utf8)
        let event = try decoder.decode(BackendEvent.self, from: data)
        #expect(event == .speechStarted)
    }

    @Test func decodeTranscription() throws {
        let data = Data(#"{"type":"transcription","text":"こんにちは","is_final":true}"#.utf8)
        let event = try decoder.decode(BackendEvent.self, from: data)
        #expect(event == .transcription(text: "こんにちは", isFinal: true))
    }

    @Test func decodeTranscriptionInterim() throws {
        let data = Data(#"{"type":"transcription","text":"こん","is_final":false}"#.utf8)
        let event = try decoder.decode(BackendEvent.self, from: data)
        #expect(event == .transcription(text: "こん", isFinal: false))
    }

    @Test func decodeSpeechEnded() throws {
        let data = Data(#"{"type":"speech_ended"}"#.utf8)
        let event = try decoder.decode(BackendEvent.self, from: data)
        #expect(event == .speechEnded)
    }

    @Test func decodeError() throws {
        let data = Data(#"{"type":"error","message":"mic not found"}"#.utf8)
        let event = try decoder.decode(BackendEvent.self, from: data)
        #expect(event == .error(message: "mic not found"))
    }

    @Test func decodeUnknownTypeThrows() throws {
        let data = Data(#"{"type":"unknown"}"#.utf8)
        #expect(throws: DecodingError.self) {
            try decoder.decode(BackendEvent.self, from: data)
        }
    }
}
