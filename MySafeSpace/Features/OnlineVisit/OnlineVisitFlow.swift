import SwiftUI

/// Teleconsultation: location check (required — the clinician must know where to send help)
/// → emergency contact check → waiting room → mock call.
struct OnlineVisitFlow: View {
    let visit: Visit

    enum Step: Hashable { case emergencyContact, waitingRoom, call }

    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var services
    @State private var path: [Step] = []
    @State private var confirmedAddress = ""

    private var clinician: Clinician? { services.directory.clinician(visit.clinicianID) }

    var body: some View {
        NavigationStack(path: $path) {
            LocationCheckView(address: $confirmedAddress) { path.append(.emergencyContact) }
                .toolbar { flowToolbar }
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .emergencyContact:
                        EmergencyContactCheckView { path.append(.waitingRoom) }
                            .toolbar { flowToolbar }
                    case .waitingRoom:
                        WaitingRoomView(clinician: clinician) { path.append(.call) }
                            .toolbar { flowToolbar }
                    case .call:
                        CallView(clinician: clinician) { dismiss() }
                    }
                }
        }
    }

    @ToolbarContentBuilder
    private var flowToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Leave") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) { NeedHelpButton() }
    }
}

// MARK: - 1. Location

struct LocationCheckView: View {
    @Binding var address: String
    let onContinue: () -> Void

    @Environment(AppServices.self) private var services
    @State private var isLocating = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Image(systemName: "location.circle")
                    .font(.system(.largeTitle, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                Text("Where are you right now?")
                    .font(.screenTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("If something urgent happens during the visit, your clinician needs to know where to send help. We need your current location – not your registered address.")
                    .foregroundStyle(Color.ink)

                Button {
                    Task { await locate() }
                } label: {
                    HStack {
                        if isLocating { ProgressView().tint(Color.brandPrimary) }
                        Label("Use my current location", systemImage: "location.fill")
                    }
                }
                .buttonStyle(.pill(.secondary))
                .disabled(isLocating)

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Or type the address")
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                    TextField("Street, number, flat, city", text: $address, axis: .vertical)
                        .textContentType(.fullStreetAddress)
                        .lineLimit(1...3)
                        .padding(Spacing.m)
                        .frame(minHeight: minTapTarget)
                        .background(Color.surface, in: .rect(cornerRadius: Radius.inner, style: .continuous))
                        .foregroundStyle(Color.ink)
                    Text("Add a flat number or floor if it helps someone find you.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                }

                InfoNote(systemImage: "lock", text: "Your location is shared with your clinician for this visit only. The app doesn't track you.")
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            Button("Confirm location", action: onContinue)
                .buttonStyle(.pill(arrow: true))
                .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).count < 5)
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.xs)
                .background(Color.appBackground.opacity(0.96))
        }
        .navigationTitle("Before your visit")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func locate() async {
        isLocating = true
        errorText = nil
        defer { isLocating = false }
        do {
            address = try await services.location.currentAddress()
        } catch LocationError.denied {
            errorText = String(localized: "Location access is off. You can type the address instead, or allow access in Settings.")
        } catch {
            errorText = String(localized: "We couldn't find your location. Please type the address instead.")
        }
    }
}

// MARK: - 2. Emergency contact

struct EmergencyContactCheckView: View {
    let onContinue: () -> Void

    @Environment(AppState.self) private var appState
    @State private var name = ""
    @State private var phone = ""
    @State private var didLoad = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text("Is your emergency contact up to date?")
                    .font(.screenTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Your clinician would only contact this person if they were seriously worried about your safety.")
                    .foregroundStyle(Color.ink)
                EmergencyContactFields(name: $name, phone: $phone)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.xs) {
                Button("Looks right") {
                    if !name.isEmpty, !phone.isEmpty {
                        appState.settings.emergencyContact = EmergencyContact(name: name, phone: phone)
                    }
                    onContinue()
                }
                .buttonStyle(.pill(arrow: true))
                Button("Skip for now", action: onContinue)
                    .font(.headline)
                    .foregroundStyle(Color.brandPrimaryStrong)
                    .frame(minHeight: minTapTarget)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xs)
            .background(Color.appBackground.opacity(0.96))
        }
        .navigationTitle("Check-in")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            name = appState.settings.emergencyContact?.name ?? ""
            phone = appState.settings.emergencyContact?.phone ?? ""
        }
    }
}

// MARK: - 3. Waiting room

struct WaitingRoomView: View {
    let clinician: Clinician?
    let onEnter: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var micOn = true
    @State private var cameraOn = true
    @State private var clinicianReady = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: Spacing.l) {
            Spacer(minLength: Spacing.m)
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.12))
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulse && !reduceMotion ? 1.08 : 1)
                    .opacity(reduceMotion && pulse ? 0.7 : 1)
                AvatarView(initials: clinician?.initials ?? "?", fill: .surface)
                    .scaleEffect(2)
            }
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { pulse = true }
            }

            VStack(spacing: Spacing.xs) {
                Group {
                    if clinicianReady {
                        Text("\(clinician?.fullName ?? "") is ready")
                    } else {
                        Text("\(clinician?.fullName ?? "") will join shortly")
                    }
                }
                .font(.screenTitle)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                Text("Take a breath. There's no rush.")
                    .secondaryText()
            }

            // Self-preview tile (mock).
            ZStack {
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .fill(Color.callBackground)
                if cameraOn {
                    MoodFace(level: .okay, size: 64).accessibilityHidden(true)
                } else {
                    Image(systemName: "video.slash").font(.title).foregroundStyle(.white)
                }
                VStack {
                    Spacer()
                    HStack {
                        Text("You").font(.caption.weight(.semibold)).foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(Spacing.s)
                }
            }
            .frame(height: 140)
            .accessibilityElement()
            .accessibilityLabel(cameraOn ? Text("Camera preview on") : Text("Camera off"))

            HStack(spacing: Spacing.l) {
                toggle(isOn: $micOn, on: "mic.fill", off: "mic.slash.fill", label: "Microphone")
                toggle(isOn: $cameraOn, on: "video.fill", off: "video.slash.fill", label: "Camera")
            }

            Spacer()
            Button("Enter visit", action: onEnter)
                .buttonStyle(.pill(arrow: true))
                .disabled(!clinicianReady)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.bottom, Spacing.m)
        .screenBackground()
        .navigationTitle("Waiting room")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            try? await Task.sleep(for: .seconds(3)) // MOCK: clinician joins
            withAnimation { clinicianReady = true }
        }
    }

    private func toggle(isOn: Binding<Bool>, on: String, off: String, label: LocalizedStringKey) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: isOn.wrappedValue ? on : off)
                .font(.title3)
                .foregroundStyle(isOn.wrappedValue ? Color.ink : Color.onBrandPrimary)
                .frame(width: 60, height: 60)
                .background(isOn.wrappedValue ? Color.surface : Color.brandPrimary, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityValue(isOn.wrappedValue ? Text("On") : Text("Off"))
    }
}

// MARK: - 4. Call (mock)

struct CallView: View {
    let clinician: Clinician?
    let onEnd: () -> Void

    @Environment(AppState.self) private var appState
    @State private var muted = false
    @State private var cameraOff = false
    @State private var confirmEnd = false
    @State private var startedAt = Date.now

    var body: some View {
        ZStack {
            Color.callBackground.ignoresSafeArea()

            // Remote tile (placeholder — no stock photos of real people).
            VStack(spacing: Spacing.s) {
                AvatarView(initials: clinician?.initials ?? "?", fill: .surfaceMuted)
                    .scaleEffect(2.4)
                    .padding(.bottom, Spacing.l)
                Text(clinician?.fullName ?? "")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityElement(children: .combine)

            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        // MOCK: no real E2EE in Phase 1 — label shows the production intent.
                        Label("End-to-end encrypted", systemImage: "lock.fill")
                            .font(.caption.weight(.semibold))
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(Duration.seconds(context.date.timeIntervalSince(startedAt)), format: .time(pattern: .minuteSecond))
                                .font(.caption.monospacedDigit())
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(Spacing.s)
                    .glassEffect(.regular, in: .rect(cornerRadius: Radius.small)) // VERIFY: iOS 26 Liquid Glass
                    Spacer()
                    Button {
                        appState.presentCrisis()
                    } label: {
                        Label("Need help now?", systemImage: "lifepreserver")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.s)
                            .frame(minHeight: minTapTarget)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(Color.ink.opacity(0.6))
                        if cameraOff {
                            Image(systemName: "video.slash").foregroundStyle(.white)
                        } else {
                            MoodFace(level: .okay, size: 44).accessibilityHidden(true)
                        }
                    }
                    .frame(width: 96, height: 128)
                    .accessibilityLabel(Text("Your video"))
                }
                HStack(spacing: Spacing.l) {
                    callButton(symbol: muted ? "mic.slash.fill" : "mic.fill", label: muted ? "Unmute" : "Mute") { muted.toggle() }
                    callButton(symbol: cameraOff ? "video.slash.fill" : "video.fill", label: cameraOff ? "Turn camera on" : "Turn camera off") { cameraOff.toggle() }
                    Button {
                        confirmEnd = true
                    } label: {
                        Image(systemName: "phone.down.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 68, height: 68)
                            .background(Color.red, in: .circle)
                    }
                    .accessibilityLabel("End visit")
                }
                .padding(.top, Spacing.m)
            }
            .padding(Spacing.m)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .statusBarHidden(false)
        .confirmationDialog("End the visit?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End visit", role: .destructive, action: onEnd)
            Button("Stay", role: .cancel) {}
        }
    }

    private func callButton(symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text(label))
    }
}

#Preview("Online visit") {
    OnlineVisitFlow(visit: MockData.visits(now: .now).first { $0.kind.isOnline }!)
        .previewEnvironment()
}

#Preview("Call") {
    CallView(clinician: MockData.directory.lead) {}
        .previewEnvironment()
}
