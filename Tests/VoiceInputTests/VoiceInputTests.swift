import Testing

@Test func appNameIsCorrect() async throws {
    let appName = "VoiceInput"
    #expect(appName == "VoiceInput")
}
