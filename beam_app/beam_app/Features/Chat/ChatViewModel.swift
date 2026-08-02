import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [Message] = []
    @Published var draftText = ""
    @Published private(set) var isSending = false
    /// messageId -> 0...1 upload fraction, for messages currently uploading media.
    @Published private(set) var uploadProgress: [String: Double] = [:]

    let conversationId: String
    private let chatRepository: ChatRepository
    private let mediaRepository: MediaRepository
    private var observeTask: Task<Void, Never>?
    private var currentUserId: String = ""

    init(
        conversationId: String,
        chatRepository: ChatRepository = FirestoreChatRepository(),
        mediaRepository: MediaRepository = CloudinaryMediaRepository()
    ) {
        self.conversationId = conversationId
        self.chatRepository = chatRepository
        self.mediaRepository = mediaRepository
    }

    /// - Parameter currentUserId: needed so we know which messages are "incoming" and can be
    ///   advanced from sent -> delivered -> read as this device receives/views them.
    func start(currentUserId: String) {
        self.currentUserId = currentUserId
        observeTask?.cancel()
        observeTask = Task {
            for await updated in chatRepository.observeMessages(conversationId: conversationId) {
                self.reconcile(with: updated)
                await self.advanceIncomingMessageStatuses(updated)
            }
        }
    }

    /// Merges the authoritative server snapshot with any optimistic messages that
    /// haven't been confirmed by the listener yet, matched by id (the client
    /// generates the message id up front and uses it as the Firestore doc id, so
    /// once the server copy arrives it always has the same id as the local one).
    private func reconcile(with serverMessages: [Message]) {
        let serverIds = Set(serverMessages.map(\.id))
        let stillPending = messages.filter { $0.status == .sending && !serverIds.contains($0.id) }
        messages = (serverMessages + stillPending).sorted { $0.createdAt < $1.createdAt }
    }

    /// This chat screen is open and rendering these messages, so anything the other
    /// participant sent that isn't already marked read gets bumped forward:
    /// - sent -> delivered (their message reached this device)
    /// - delivered -> read (the recipient is actively looking at this conversation)
    /// Real "online delivery" would need a presence/Cloud Functions backend (Phase 1
    /// intentionally has neither), so both hops happen client-side, here, on receipt.
    private func advanceIncomingMessageStatuses(_ messages: [Message]) async {
        guard !currentUserId.isEmpty else { return }

        let toDeliver = messages.filter { $0.senderId != currentUserId && $0.status == .sent }.map(\.id)
        if !toDeliver.isEmpty {
            do {
                try await chatRepository.updateMessageStatuses(
                    conversationId: conversationId, messageIds: toDeliver, status: .delivered
                )
            } catch {
                // If this prints "Missing or insufficient permissions", your Firestore
                // security rules only allow a message's sender to update it — the
                // recipient needs write access to bump status too. See the rules
                // snippet in the chat notes.
                print("markDelivered error: \(error)")
            }
        }

        let toRead = messages.filter { $0.senderId != currentUserId && ($0.status == .sent || $0.status == .delivered) }.map(\.id)
        if !toRead.isEmpty {
            do {
                try await chatRepository.updateMessageStatuses(
                    conversationId: conversationId, messageIds: toRead, status: .read
                )
            } catch {
                print("markRead error: \(error)")
            }
        }
    }

    func stop() {
        observeTask?.cancel()
    }

    /// Uploads a picked/recorded photo, video, or voice clip and sends it as a message.
    /// Mirrors sendDraft()'s optimistic-echo/failure pattern, plus a progress readout
    /// for the upload itself since media transfers can take a few seconds.
    func sendMedia(senderId: String, data: Data, kind: MediaKind, duration: Double? = nil) async {
        let type: MessageType = {
            switch kind {
            case .image: return .image
            case .video: return .video
            case .audio: return .audio
            }
        }()

        var message = Message.mediaDraft(conversationId: conversationId, senderId: senderId, type: type, duration: duration)
        messages.append(message)
        uploadProgress[message.id] = 0

        do {
            let result = try await mediaRepository.upload(data: data, kind: kind) { [weak self] fraction in
                self?.uploadProgress[message.id] = fraction
            }
            message.mediaURL = result.url
            message.duration = message.duration ?? result.duration
            message.status = .sent
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index] = message
            }
            try await chatRepository.sendMessage(message)
        } catch {
            print("sendMedia error: \(error)")
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].status = .failed
            }
        }
        uploadProgress[message.id] = nil
    }

    func sendDraft(senderId: String) async {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        draftText = ""
        isSending = true
        defer { isSending = false }

        let message = Message.draft(conversationId: conversationId, senderId: senderId, text: trimmed)

        // Optimistic local echo: show it instantly instead of waiting on the
        // realtime listener round-trip.
        messages.append(message)

        do {
            try await chatRepository.sendMessage(message)
        } catch {
            print("sendMessage error: \(error)")
            // Reflect the failure on the bubble itself rather than losing it silently.
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].status = .failed
            }
            // Restore the draft so the user doesn't lose what they typed.
            draftText = trimmed
        }
    }
}
