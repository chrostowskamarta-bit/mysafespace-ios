import SwiftUI

/// Secure messaging with the care team. No phone numbers are exchanged.
struct MessagesView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services

    var body: some View {
        @Bindable var appState = appState
        NavigationStack(path: $appState.messagesPath) {
            List {
                Section {
                    EmergencyBanner()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(services.messaging.threads) { thread in
                        NavigationLink(value: thread.id) {
                            ThreadRow(thread: thread)
                        }
                        .listRowBackground(Color.surface)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listScreenBackground()
            .navigationTitle("Messages")
            .navigationDestination(for: MessageThread.ID.self) { id in
                ThreadView(threadID: id)
            }
        }
    }
}

struct ThreadRow: View {
    let thread: MessageThread
    @Environment(AppServices.self) private var services

    var body: some View {
        let clinician = services.directory.clinician(thread.clinicianID)
        let last = services.messaging.messages(in: thread.id).last
        HStack(spacing: Spacing.s) {
            ClinicianPhoto(clinician: clinician, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(clinician?.fullName ?? "")
                        .font(.headline)
                    Spacer()
                    if let last {
                        Text(last.sentAt, format: .relative(presentation: .named))
                            .font(.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                Text(clinician?.role.label ?? "")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                if let last {
                    Text(last.text)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(2)
                        .privacySensitive()
                }
            }
            .foregroundStyle(Color.ink)
        }
        .padding(.vertical, Spacing.xxs)
    }
}

struct ThreadView: View {
    let threadID: MessageThread.ID

    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services
    @State private var draft = ""
    @State private var attachment: String?
    @FocusState private var composerFocused: Bool

    private var thread: MessageThread? { services.messaging.threads.first { $0.id == threadID } }
    private var clinician: Clinician? { thread.flatMap { services.directory.clinician($0.clinicianID) } }
    private var messages: [Message] { services.messaging.messages(in: threadID) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.s) {
                    if let clinician { expectations(clinician) }
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.s)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .screenBackground()
        .safeAreaInset(edge: .top, spacing: 0) {
            EmergencyBanner()
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.xs)
                .background(Color.appBackground)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .hidesFloatingHelpButton()
        .navigationTitle(clinician?.fullName ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Response expectations: bounded messaging, so nobody feels they're intruding.
    private func expectations(_ clinician: Clinician) -> some View {
        VStack(spacing: Spacing.xs) {
            ClinicianPhoto(clinician: clinician, size: 56)
            Text("\(clinician.shortName) \(clinician.replyExpectation)")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(clinician.officeHours.summary)
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
            // MOCK: production messaging is end-to-end encrypted.
            Label("Encrypted", systemImage: "lock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
        }
        .foregroundStyle(Color.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.m)
        .accessibilityElement(children: .combine)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let attachment {
                HStack {
                    Label(attachment, systemImage: "doc.fill")
                        .font(.footnote.weight(.medium))
                    Button {
                        self.attachment = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .frame(width: minTapTarget, height: minTapTarget)
                    }
                    .accessibilityLabel("Remove attachment")
                }
                .foregroundStyle(Color.ink)
                .padding(.leading, Spacing.s)
                .background(Color.surfaceMuted, in: .capsule)
            }
            HStack(alignment: .bottom, spacing: Spacing.xs) {
                Menu {
                    // MOCK: real attachments use the system photo/document pickers and E2EE upload.
                    Button("Photo (demo)", systemImage: "photo") { attachment = "photo.jpg" }
                    Button("Document (demo)", systemImage: "doc") { attachment = "lab-results.pdf" }
                } label: {
                    Image(systemName: "paperclip")
                        .font(.title3)
                        .foregroundStyle(Color.ink)
                        .frame(width: minTapTarget, height: minTapTarget)
                }
                .accessibilityLabel("Add attachment")

                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, 10)
                    .background(Color.surface, in: .rect(cornerRadius: 22, style: .continuous))
                    .foregroundStyle(Color.ink)

                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.onBrandPrimary)
                        .frame(width: minTapTarget, height: minTapTarget)
                        .background(Color.brandPrimary, in: .circle)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachment == nil)
                .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachment == nil ? 0.45 : 1)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.vertical, Spacing.xs)
        .background(Color.appBackground)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let file = attachment
        guard let clinician, !text.isEmpty || file != nil else { return }
        draft = ""
        attachment = nil
        // Detection runs on outgoing messages too: support is shown, sending is never blocked.
        let assessment = services.crisisDetector.assess(text)
        Task {
            await services.messaging.send(text, attachmentName: file, in: threadID, officeHours: clinician.officeHours, clinicianName: clinician.shortName)
        }
        appState.handle(assessment, source: .message, key: "thread-\(threadID)", safetyAlerts: services.safetyAlerts)
    }
}

struct MessageBubble: View {
    let message: Message

    var body: some View {
        switch message.sender {
        case .system:
            Label(message.text, systemImage: "clock")
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(Spacing.s)
                .frame(maxWidth: .infinity)
                .background(Color.surfaceMuted, in: .rect(cornerRadius: Radius.small, style: .continuous))
                .accessibilityLabel(Text("Automatic note: \(message.text)"))
        case .patient:
            bubble(alignment: .trailing, fill: .brandPrimary, text: .onBrandPrimary, prefix: String(localized: "You"))
        case .clinician:
            bubble(alignment: .leading, fill: .surface, text: .ink, prefix: nil)
        }
    }

    private func bubble(alignment: HorizontalAlignment, fill: Color, text: Color, prefix: String?) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let name = message.attachmentName {
                    Label(name, systemImage: "doc.fill")
                        .font(.footnote.weight(.semibold))
                }
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.body)
                        .privacySensitive()
                }
            }
            .foregroundStyle(text)
            .padding(.horizontal, Spacing.s + 2)
            .padding(.vertical, 10)
            .background(fill, in: .rect(cornerRadius: 20, style: .continuous))
            Text(message.sentAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
        .padding(alignment == .trailing ? .leading : .trailing, 40)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Messages") {
    MessagesView().previewEnvironment()
}

#Preview("Thread") {
    NavigationStack { ThreadView(threadID: MockData.nowakThreadID) }.previewEnvironment()
}
