import Foundation

nonisolated struct MessageThread: Identifiable, Hashable, Sendable {
    let id: String
    let clinicianID: String
}

nonisolated struct Message: Identifiable, Hashable, Sendable {
    enum Sender: Hashable, Sendable {
        case patient
        case clinician(id: String)
        /// Automatic notes (e.g. outside office hours). Never written by a person.
        case system
    }

    let id: UUID
    let threadID: String
    let sender: Sender
    let text: String
    let sentAt: Date
    var attachmentName: String?

    init(id: UUID = UUID(), threadID: String, sender: Sender, text: String, sentAt: Date, attachmentName: String? = nil) {
        self.id = id
        self.threadID = threadID
        self.sender = sender
        self.text = text
        self.sentAt = sentAt
        self.attachmentName = attachmentName
    }
}
