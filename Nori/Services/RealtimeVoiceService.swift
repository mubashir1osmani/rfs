import AVFoundation
import Combine
import Foundation
@preconcurrency import WebRTC

@MainActor
final class RealtimeVoiceService: NSObject, ObservableObject {
    enum Status: Equatable {
        case idle
        case connecting
        case listening
        case thinking
        case speaking

        var label: String {
            switch self {
            case .idle: "Voice"
            case .connecting: "Connecting"
            case .listening: "Listening"
            case .thinking: "Thinking"
            case .speaking: "Speaking"
            }
        }
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var liveTranscript = ""
    @Published var errorMessage: String?

    var onUserTranscript: ((String) -> Void)?
    var onAssistantTranscript: ((String) -> Void)?
    var onAction: ((AssistantAction) -> Void)?

    private let configuration: AppConfiguration
    private let peerFactory = RTCPeerConnectionFactory()
    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var audioTrack: RTCAudioTrack?
    private var context: AssistantContext?
    private var assistantTranscript = ""

    init(configuration: AppConfiguration = .current) {
        self.configuration = configuration
        super.init()
    }

    var isActive: Bool { status != .idle }

    func toggle(context: AssistantContext) async {
        if isActive {
            stop()
        } else {
            await start(context: context)
        }
    }

    func stop() {
        audioTrack?.isEnabled = false
        dataChannel?.close()
        peerConnection?.close()
        dataChannel = nil
        peerConnection = nil
        audioTrack = nil
        context = nil
        assistantTranscript = ""
        liveTranscript = ""
        status = .idle
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func start(context: AssistantContext) async {
        guard await microphonePermission() else {
            errorMessage = "Enable Microphone access in Settings to talk to Nori."
            return
        }
        guard configuration.openAIKey != nil else {
            errorMessage = "Add your OpenAI API key in Settings before starting Realtime voice."
            return
        }

        do {
            status = .connecting
            self.context = context
            try configureAudioSession()
            let token = try await createClientSecret()
            let peer = makePeerConnection()
            peerConnection = peer
            let channelConfiguration = RTCDataChannelConfiguration()
            channelConfiguration.isOrdered = true
            dataChannel = peer.dataChannel(forLabel: "oai-events", configuration: channelConfiguration)
            dataChannel?.delegate = self

            let audioSource = peerFactory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
            let track = peerFactory.audioTrack(with: audioSource, trackId: "nori-audio")
            audioTrack = track
            _ = peer.add(track, streamIds: ["nori-stream"])

            let offer = try await createOffer(peer)
            try await setLocalDescription(offer, on: peer)
            let answer = try await exchangeSDP(offer.sdp, token: token)
            try await setRemoteDescription(RTCSessionDescription(type: .answer, sdp: answer), on: peer)
        } catch {
            stop()
            errorMessage = error.localizedDescription
        }
    }

    private func makePeerConnection() -> RTCPeerConnection {
        let configuration = RTCConfiguration()
        configuration.sdpSemantics = .unifiedPlan
        configuration.continualGatheringPolicy = .gatherContinually
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        return peerFactory.peerConnection(with: configuration, constraints: constraints, delegate: self)
    }

    private func createClientSecret() async throws -> String {
        guard let apiKey = configuration.openAIKey else { throw VoiceError.notConfigured }
        var request = URLRequest(url: configuration.realtimeClientSecretsURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.userID, forHTTPHeaderField: "OpenAI-Safety-Identifier")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "session": [
                "type": "realtime",
                "model": "gpt-realtime-2.1",
                "audio": ["output": ["voice": "marin"]],
            ],
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw VoiceError.serviceError(errorMessage(from: data))
        }
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let nested = payload?["client_secret"] as? [String: Any]
        guard let token = payload?["value"] as? String ?? nested?["value"] as? String else {
            throw VoiceError.invalidResponse
        }
        return token
    }

    private func exchangeSDP(_ sdp: String, token: String) async throws -> String {
        var request = URLRequest(url: configuration.realtimeCallsURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(sdp.utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              let answer = String(data: data, encoding: .utf8), !answer.isEmpty else {
            throw VoiceError.serviceError(errorMessage(from: data))
        }
        return answer
    }

    private func sendSessionUpdate() {
        let contextData = context.flatMap { try? JSONEncoder.nori.encode($0) }
        let contextJSON = contextData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        send([
            "type": "session.update",
            "session": [
                "type": "realtime",
                "output_modalities": ["audio"],
                "instructions": """
                You are Nori, an autonomous personal assistant. Be concise, warm, and action-oriented.
                Use tools whenever the user asks to create a task, schedule time, book a meeting, or send an email.
                External actions are prepared for approval in the app; never claim they already happened.
                Current context: \(contextJSON)
                """,
                "audio": [
                    "input": [
                        "transcription": ["model": "gpt-4o-mini-transcribe"],
                        "turn_detection": [
                            "type": "server_vad",
                            "create_response": true,
                            "interrupt_response": true,
                            "silence_duration_ms": 550,
                        ],
                    ],
                    "output": ["voice": "marin"],
                ],
                "reasoning": ["effort": "low"],
                "tools": Self.tools,
                "tool_choice": "auto",
                "parallel_tool_calls": false,
                "max_output_tokens": 1_024,
            ],
        ])
    }

    private func send(_ event: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: event) else { return }
        dataChannel?.sendData(RTCDataBuffer(data: data, isBinary: false))
    }

    private func handle(_ event: [String: Any]) {
        guard let type = event["type"] as? String else { return }
        switch type {
        case "input_audio_buffer.speech_started":
            status = .listening
        case "input_audio_buffer.speech_stopped":
            status = .thinking
        case "conversation.item.input_audio_transcription.completed":
            if let transcript = event["transcript"] as? String, !transcript.isEmpty {
                liveTranscript = transcript
                onUserTranscript?(transcript)
            }
        case "response.output_audio_transcript.delta", "response.output_text.delta":
            if let delta = event["delta"] as? String {
                assistantTranscript += delta
                liveTranscript = assistantTranscript
                status = .speaking
            }
        case "response.output_audio_transcript.done", "response.output_text.done":
            finishAssistantTranscript()
        case "response.output_item.done":
            handleToolCall(event["item"] as? [String: Any])
        case "response.done":
            finishAssistantTranscript()
            if status != .idle { status = .listening }
        case "error":
            let error = event["error"] as? [String: Any]
            let message = error?["message"] as? String ?? "Realtime voice failed."
            stop()
            errorMessage = message
        default:
            break
        }
    }

    private func finishAssistantTranscript() {
        let clean = assistantTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        onAssistantTranscript?(clean)
        assistantTranscript = ""
        liveTranscript = ""
    }

    private func handleToolCall(_ item: [String: Any]?) {
        guard let item, item["type"] as? String == "function_call",
              let name = item["name"] as? String,
              let callID = item["call_id"] as? String,
              let arguments = item["arguments"] as? String,
              let data = arguments.data(using: .utf8),
              let values = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = Self.action(name: name, values: values) else { return }
        onAction?(action)
        send([
            "type": "conversation.item.create",
            "item": [
                "type": "function_call_output",
                "call_id": callID,
                "output": "{\"status\":\"awaiting_user_approval\"}",
            ],
        ])
        send(["type": "response.create"])
    }

    private static func action(name: String, values: [String: Any]) -> AssistantAction? {
        switch name {
        case "create_task":
            let category = TaskItem.Category(rawValue: values["category"] as? String ?? "Personal") ?? .personal
            return .task(
                title: values["title"] as? String ?? "New priority",
                dueLabel: values["dueLabel"] as? String ?? "Today",
                category: category
            )
        case "create_calendar_event":
            let start = (values["start"] as? String).flatMap(ISO8601DateFormatter().date) ?? Date().addingTimeInterval(3_600)
            return .calendar(
                kind: values["isMeeting"] as? Bool == true ? .meeting : .calendar,
                title: values["title"] as? String ?? "Focus block",
                start: start,
                durationMinutes: values["durationMinutes"] as? Int ?? 60,
                notes: values["notes"] as? String ?? "Planned with Nori",
                attendees: values["attendees"] as? [String] ?? []
            )
        case "send_email":
            return .email(
                to: values["to"] as? String ?? "",
                subject: values["subject"] as? String ?? "Quick follow-up",
                body: values["body"] as? String ?? ""
            )
        default:
            return nil
        }
    }

    private static var tools: [[String: Any]] {
        [
            tool(
                name: "create_task",
                description: "Create a task in Nori.",
                properties: [
                    "title": ["type": "string"],
                    "dueLabel": ["type": "string"],
                    "category": ["type": "string", "enum": ["Work", "School", "Personal"]],
                ],
                required: ["title", "dueLabel", "category"]
            ),
            tool(
                name: "create_calendar_event",
                description: "Prepare a calendar event or meeting for approval.",
                properties: [
                    "title": ["type": "string"],
                    "start": ["type": "string"],
                    "durationMinutes": ["type": "integer", "minimum": 15, "maximum": 480],
                    "notes": ["type": "string"],
                    "attendees": ["type": "array", "items": ["type": "string"]],
                    "isMeeting": ["type": "boolean"],
                ],
                required: ["title", "start", "durationMinutes", "notes", "attendees", "isMeeting"]
            ),
            tool(
                name: "send_email",
                description: "Prepare an email for approval.",
                properties: [
                    "to": ["type": "string"],
                    "subject": ["type": "string"],
                    "body": ["type": "string"],
                ],
                required: ["to", "subject", "body"]
            ),
        ]
    }

    private static func tool(
        name: String,
        description: String,
        properties: [String: Any],
        required: [String]
    ) -> [String: Any] {
        [
            "type": "function",
            "name": name,
            "description": description,
            "parameters": [
                "type": "object",
                "additionalProperties": false,
                "properties": properties,
                "required": required,
            ],
        ]
    }

    private func createOffer(_ peer: RTCPeerConnection) async throws -> RTCSessionDescription {
        try await withCheckedThrowingContinuation { continuation in
            peer.offer(for: RTCMediaConstraints(
                mandatoryConstraints: ["OfferToReceiveAudio": "true"],
                optionalConstraints: nil
            )) { description, error in
                if let description { continuation.resume(returning: description) }
                else { continuation.resume(throwing: error ?? VoiceError.invalidResponse) }
            }
        }
    }

    private func setLocalDescription(_ description: RTCSessionDescription, on peer: RTCPeerConnection) async throws {
        try await withCheckedThrowingContinuation { continuation in
            peer.setLocalDescription(description) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func setRemoteDescription(_ description: RTCSessionDescription, on peer: RTCPeerConnection) async throws {
        try await withCheckedThrowingContinuation { continuation in
            peer.setRemoteDescription(description) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
    }

    private func microphonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    private func errorMessage(from data: Data) -> String {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "OpenAI could not start the Realtime session."
        }
        if let error = payload["error"] as? String { return error }
        if let error = payload["error"] as? [String: Any], let message = error["message"] as? String { return message }
        return "OpenAI could not start the Realtime session."
    }
}

extension RealtimeVoiceService: RTCDataChannelDelegate {
    nonisolated func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        guard dataChannel.readyState == .open else { return }
        Task { @MainActor in
            status = .listening
            sendSessionUpdate()
        }
    }

    nonisolated func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        let data = buffer.data
        Task { @MainActor in
            guard let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            handle(event)
        }
    }
}

extension RealtimeVoiceService: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        guard newState == .failed || newState == .disconnected || newState == .closed else { return }
        Task { @MainActor in
            if status != .idle { errorMessage = "Realtime voice disconnected." }
            stop()
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        Task { @MainActor in
            self.dataChannel = dataChannel
            dataChannel.delegate = self
        }
    }
}

private enum VoiceError: LocalizedError {
    case invalidResponse
    case notConfigured
    case serviceError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "OpenAI returned an invalid Realtime response."
        case .notConfigured: "OpenAI is not configured."
        case let .serviceError(message): message
        }
    }
}
