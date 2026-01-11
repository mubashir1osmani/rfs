//
//  SpeechService.swift
//  rufus
//
//  Created by AI Assistant
//

import Foundation
import AVFoundation
import Speech

@MainActor
class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    @Published var isRecording = false
    @Published var transcription = ""
    @Published var transcribedText = ""

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private override init() {
        super.init()
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startRecording() throws {
        isRecording = true
        transcription = ""
    }

    func stopRecording() {
        isRecording = false
    }
}
