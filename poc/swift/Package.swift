// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SpeechRecognitionPoC",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "whisperkit-realtime",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "Sources/whisperkit-realtime",
            exclude: ["Entitlements.plist"]
        ),
        .executableTarget(
            name: "apple-speech-realtime",
            path: "Sources/apple-speech-realtime",
            exclude: ["Entitlements.plist", "Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/apple-speech-realtime/Info.plist",
                ]),
            ]
        ),
    ]
)
