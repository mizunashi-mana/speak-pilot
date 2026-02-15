/// JSON lines protocol types for communication with the Python STT server.
///
/// Commands are sent from Swift to Python via stdin.
/// Events are received from Python via stdout.

import Foundation

// MARK: - Commands (Swift → Python)

enum BackendCommand: Sendable {
    case start
    case stop
    case shutdown
}

extension BackendCommand: Encodable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .start:
            try container.encode("start", forKey: .type)
        case .stop:
            try container.encode("stop", forKey: .type)
        case .shutdown:
            try container.encode("shutdown", forKey: .type)
        }
    }
}

// MARK: - Events (Python → Swift)

enum BackendEvent: Sendable, Equatable {
    case ready
    case speechStarted
    case transcription(text: String, isFinal: Bool)
    case speechEnded
    case error(message: String)
}

extension BackendEvent: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case isFinal = "is_final"
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "ready":
            self = .ready
        case "speech_started":
            self = .speechStarted
        case "transcription":
            let text = try container.decode(String.self, forKey: .text)
            let isFinal = try container.decode(Bool.self, forKey: .isFinal)
            self = .transcription(text: text, isFinal: isFinal)
        case "speech_ended":
            self = .speechEnded
        case "error":
            let message = try container.decode(String.self, forKey: .message)
            self = .error(message: message)
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: [CodingKeys.type], debugDescription: "Unknown event type: \(type)")
            )
        }
    }
}
