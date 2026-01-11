// VoiceAssistantViewModel.swift
// Minimal Siri-like assistant: speech recognition, TTS, and simple intent parsing.

import Foundation
import AVFoundation
import Speech

@MainActor
final class VoiceAssistantViewModel: ObservableObject {
    // Published state for UI
    @Published var isListening: Bool = false
    @Published var transcript: String = ""
    @Published var response: String = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.preferredLanguages.first ?? "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Public API
    func requestPermissions() async {
        // Request speech recognition permission
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    self?.authorizationStatus = status
                    cont.resume()
                }
            }
        }
        // Request microphone permission
        _ = await AVAudioSession.sharedInstance().requestRecordPermission()
    }

    func toggleListening() {
        isListening ? stopListening() : startListening()
    }

    func startListening() {
        guard !audioEngine.isRunning else { return }
        transcript = ""
        response = ""
        isListening = true

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session error: \(error)")
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("AudioEngine couldn't start: \(error)")
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                Task { @MainActor in
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.finishRecognition()
                    }
                }
            }
            if error != nil {
                Task { @MainActor in
                    self.finishRecognition()
                }
            }
        }
    }

    func stopListening() {
        finishRecognition()
    }

    private func finishRecognition() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
        handleCommand(transcript)
    }

    // MARK: - Intent Parsing (very simple heuristics)
    private func handleCommand(_ text: String) {
        let lower = text.lowercased()
        guard !lower.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if lower.contains("meeting") || lower.contains("schedule") {
            // Extract a simple title and when (very naive)
            let title = extractTitle(from: lower, keywords: ["meeting", "schedule", "with"]) ?? "Meeting"
            let when = extractWhen(from: lower)
            scheduleMeeting(title: title, when: when, attendees: [])
        } else if lower.contains("remind") || lower.contains("reminder") {
            let title = extractTitle(from: lower, keywords: ["remind", "reminder", "to"]) ?? "Reminder"
            let when = extractWhen(from: lower)
            addReminder(title: title, when: when)
        } else if lower.contains("task") || lower.contains("to-do") || lower.contains("todo") || lower.contains("add") {
            let title = extractTitle(from: lower, keywords: ["task", "to-do", "todo", "add"]) ?? "Task"
            let when = extractWhen(from: lower)
            addTodo(title: title, due: when)
        } else {
            respond("I heard: \(text). How can I help you with tasks, meetings, or reminders?")
        }
    }

    // MARK: - Hooks you can connect to your data layer
    private func addTodo(title: String, due: Date?) {
        // TODO: Connect to your Assignments/Tasks store
        let whenString = due.map { Self.relativeFormatter.string(from: $0) } ?? "no due date"
        respond("Added task ‘\(title)’ with \(whenString).")
    }

    private func addReminder(title: String, when: Date?) {
        // TODO: Connect to Reminders store (or EventKit)
        let whenString = when.map { Self.relativeFormatter.string(from: $0) } ?? "no time set"
        respond("I set a reminder ‘\(title)’ for \(whenString).")
    }

    private func scheduleMeeting(title: String, when: Date?, attendees: [String]) {
        // TODO: Connect to your meetings/calendar integration
        let whenString = when.map { Self.relativeFormatter.string(from: $0) } ?? "no time set"
        respond("Scheduled ‘\(title)’ for \(whenString).")
    }

    // MARK: - Speaking
    private func respond(_ text: String) {
        response = text
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    // MARK: - Naive NLP helpers
    private func extractTitle(from text: String, keywords: [String]) -> String? {
        var working = text
        for k in keywords { working = working.replacingOccurrences(of: k, with: " ") }
        working = working.replacingOccurrences(of: "  ", with: " ")
        working = working.trimmingCharacters(in: .whitespacesAndNewlines)
        // Try to remove time words crudely
        let timeWords = ["today", "tomorrow", "next", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "am", "pm"]
        var tokens = working.split(separator: " ").map(String.init)
        tokens.removeAll { timeWords.contains($0) }
        return tokens.isEmpty ? nil : tokens.joined(separator: " ")
    }

    private func extractWhen(from text: String) -> Date? {
        // Very naive date parsing: today/tomorrow and simple times like 5pm/8:30am
        let lower = text.lowercased()
        let now = Date()
        var dayOffset = 0
        if lower.contains("tomorrow") { dayOffset = 1 }
        else if lower.contains("today") { dayOffset = 0 }
        else if lower.contains("next") { dayOffset = 7 } // next week heuristic

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
        comps.day = (comps.day ?? 0) + dayOffset

        // Time parsing
        var hour: Int? = nil
        var minute: Int = 0
        if let match = lower.range(of: #"\b(\d{1,2})(:(\d{2}))?\s?(am|pm)\b"#, options: .regularExpression) {
            let token = String(lower[match])
            let parts = token.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ":", with: ":").split(separator: ":")
            if let h = Int(parts.first ?? ""), h >= 1, h <= 12 {
                hour = h
            }
            if parts.count >= 2, let m = Int(parts[1].prefix(2)) { minute = m }
            let isPM = token.contains("pm")
            if var h = hour {
                if isPM && h < 12 { h += 12 }
                if !isPM && h == 12 { h = 0 }
                hour = h
            }
        } else if let match = lower.range(of: #"\b(\d{1,2})\s?(am|pm)\b"#, options: .regularExpression) {
            let token = String(lower[match])
            if let h = Int(token.filter({ $0.isNumber })) { hour = h }
            let isPM = token.contains("pm")
            if var h = hour {
                if isPM && h < 12 { h += 12 }
                if !isPM && h == 12 { h = 0 }
                hour = h
            }
        }

        if let hour = hour {
            comps.hour = hour
            comps.minute = minute
            return Calendar.current.date(from: comps)
        } else if dayOffset != 0 {
            return Calendar.current.date(from: comps)
        }
        return nil
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
}
