//
//  TextToSpeechService.swift
//  rufus
//
//  Created by AI Assistant
//

import Foundation
import AVFoundation

@MainActor
class TextToSpeechService: NSObject, ObservableObject {
    static let shared = TextToSpeechService()

    @Published var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func speak(text: String) {
        speak(text)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func stopSpeaking() {
        stop()
    }
}

extension TextToSpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }
}
