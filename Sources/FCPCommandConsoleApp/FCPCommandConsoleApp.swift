import AVKit
import AppKit
import FCPCommandConsoleCore
import SwiftUI
import UniformTypeIdentifiers

@main
struct FCPCommandConsoleApp: App {
    var body: some Scene {
        WindowGroup("FCPCommandConsole") {
            ContentView()
                // Opens tall enough to show the preview and its controls
                // without scrolling on a normal display. The content scrolls
                // regardless, so a smaller window degrades rather than clips.
                .frame(minWidth: 900, idealWidth: 1000, minHeight: 680, idealHeight: 980)
        }
    }
}

@MainActor
private final class AppModel: ObservableObject {
    @Published var command = "" { didSet { invalidatePlanIfInputsDrifted() } }
    @Published var primary: LocalMediaAsset? { didSet { invalidatePlanIfInputsDrifted() } }
    @Published var outgoing: LocalMediaAsset? { didSet { invalidatePlanIfInputsDrifted() } }
    @Published var incoming: LocalMediaAsset? { didSet { invalidatePlanIfInputsDrifted() } }
    /// A texture composited above the primary clip. Optional, and not part of
    /// the edit — so it is deliberately absent from the structure lock.
    @Published var overlay: LocalMediaAsset? { didSet { invalidatePlanIfInputsDrifted() } }
    @Published var target: Target? { didSet { invalidatePlanIfInputsDrifted() } }
    @Published var result: LocalMediaPlanningResult?
    @Published var package: LocalPlanPackage?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?
    @Published var loadingRole: LocalMediaRole?
    @Published var isSavingPackage = false
    @Published var isCancellingPackage = false
    @Published var isExportingProject = false
    @Published var exportedProject: StandaloneFCPXMLExportBuilder.Package?
    /// Channels for the current plan, sampled by the preview. Cleared with the
    /// plan so a stale preview can never outlive what produced it.
    @Published var previewChannels: NativeFCPXMLEffectChannels?
    // MARK: Surprise Me
    @Published var treatmentOptions: TreatmentOptionSet?
    @Published var appliedTreatment: TreatmentPlan?
    @Published var isGeneratingOptions = false

    /// The Final Cut build on this machine, read once.
    ///
    /// `nil` means Final Cut is not where it was expected, which is not an
    /// error — it just means no semantic profile applies and every FCPXML
    /// pathway stays closed, which is the correct default.
    let installedFinalCut: FinalCutVersionIdentity? = InstalledFinalCutVersionReader().read()

    /// The gate the planner uses, carrying whatever the installed build admits.
    ///
    /// Built from the profile rather than left empty: an empty gate would
    /// refuse everything, and the app would show the user a permanent refusal
    /// for workflows that are in fact admitted on their machine.
    private var capabilityGate: CapabilityGate {
        CapabilityGate(
            manualSemanticsEvidence: installedFinalCut
                .map { FinalCutSemanticProfileStore.evidence(forInstalled: $0) } ?? .unknown
        )
    }

    /// What the app may honestly say about Final Cut support right now.
    var finalCutStatus: String {
        guard let installedFinalCut else {
            return "Final Cut Pro was not found. Project generation is unavailable."
        }
        let admitted = FinalCutSemanticProfileStore.profile(for: installedFinalCut)?.admittedContracts.count ?? 0
        guard admitted > 0 else {
            return "Final Cut \(installedFinalCut.description) has no verified profile. Project generation is unavailable until the manual passes are re-run against this build."
        }
        return "Verified against Final Cut \(installedFinalCut.description)."
    }
    private var admissionTasks: [LocalMediaRole: Task<AdmissionOutcome, Never>] = [:]
    private var admissionGeneration = LocalMediaOperationGeneration()
    private var packageTask: Task<PackageOutcome, Never>?

    /// What a plan made right now would be derived from.
    private var currentInputs: LocalMediaPlanInputs {
        LocalMediaPlanInputs(request: command, target: target, primary: primary, outgoing: outgoing, incoming: incoming)
    }

    /// Drops a plan the moment it stops describing what is on screen. Without
    /// this, editing the command or moving the target leaves a stale plan
    /// summary visible and packageable — every hash inside it still verifies,
    /// so nothing downstream would notice.
    private func invalidatePlanIfInputsDrifted() {
        guard let result, let staleness = result.staleness(against: currentInputs) else { return }
        self.result = nil
        package = nil
        exportedProject = nil
        previewChannels = nil
        noticeMessage = staleness.reason
        cancelPackage()
    }

    private enum AdmissionOutcome: Sendable {
        case admitted(LocalMediaAsset)
        case failed(String)
        case cancelled
    }

    private enum PackageOutcome: Sendable {
        case built(LocalPlanPackage)
        case failed(String)
        case cancelled
    }

    func admit(_ url: URL, as role: LocalMediaRole) {
        admissionTasks[role]?.cancel()
        let token = admissionGeneration.begin(role)
        loadingRole = role
        errorMessage = nil
        let admission = LocalMediaAdmission()
        let task = Task.detached(priority: .userInitiated) { () -> AdmissionOutcome in
            do {
                let media = try await admission.admit(url)
                return Task.isCancelled ? .cancelled : .admitted(media)
            } catch is CancellationError {
                return .cancelled
            } catch {
                return Task.isCancelled ? .cancelled : .failed(error.localizedDescription)
            }
        }
        admissionTasks[role] = task
        Task { [weak self] in
            let outcome = await task.value
            guard let self, self.admissionGeneration.isCurrent(token, for: role) else { return }
            self.admissionTasks[role] = nil
            if self.loadingRole == role { self.loadingRole = nil }
            switch outcome {
            case .admitted(let media): self.assign(media, to: role)
            case .failed(let message): self.errorMessage = message
            case .cancelled: break
            }
        }
    }

    func cancelAdmission() {
        for task in admissionTasks.values { task.cancel() }
        admissionTasks.removeAll()
        admissionGeneration.cancelAll()
        loadingRole = nil
    }

    func clear(_ role: LocalMediaRole) {
        switch role {
        case .primary: primary = nil
        case .outgoing: outgoing = nil
        case .incoming: incoming = nil
        case .overlay: overlay = nil
        }
        target = nil
        result = nil
        package = nil
        errorMessage = nil
        noticeMessage = nil
    }

    func clearAll() {
        cancelAdmission()
        cancelPackage()
        primary = nil
        outgoing = nil
        incoming = nil
        target = nil
        result = nil
        package = nil
        errorMessage = nil
        noticeMessage = nil
        command = ""
    }

    private func assign(_ media: LocalMediaAsset, to role: LocalMediaRole) {
        switch role {
        case .primary: primary = media
        case .outgoing: outgoing = media
        case .incoming: incoming = media
        case .overlay: overlay = media
        }
    }

    func plan() {
        errorMessage = nil
        noticeMessage = nil
        result = nil
        package = nil
        exportedProject = nil
        previewChannels = nil
        do {
            let registryURL = try appResource(named: "registry/effects")
            let schemaURL = try appResource(named: "schemas/effect-plan.schema.json")
            let session = LocalMediaPlannerSession(
                registry: try EffectRegistry.load(from: registryURL),
                schemaValidator: try PlanSchemaValidator(schemaURL: schemaURL),
                capabilityGate: capabilityGate
            )
            let planned = try session.plan(request: command, primary: primary, outgoing: outgoing, incoming: incoming, target: target)
            result = planned
            previewChannels = effectChannels(for: planned)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Surprise Me

    /// Offers up to three treatments that leave the edit exactly as the user
    /// made it.
    ///
    /// The structure lock is established from the media **in the order the user
    /// supplied it** and every option carries its fingerprint, so a treatment
    /// that drifted could not be shown even if one were generated.
    func surpriseMe() {
        errorMessage = nil
        noticeMessage = nil
        treatmentOptions = nil
        appliedTreatment = nil
        isGeneratingOptions = true
        defer { isGeneratingOptions = false }

        let ordered = orderedMedia()
        guard !ordered.isEmpty else {
            errorMessage = "Add some media first — Surprise Me treats your clips, it does not choose them."
            return
        }
        do {
            let cardsURL = try appResource(named: "registry/editorial-techniques")
            let catalog = try EditorialKnowledgeCatalog.load(from: cardsURL)
            let lock = EditorialStructureLock.establish(
                orderedMedia: ordered,
                clipDurationFrames: ordered.map { _ in 120 }
            )
            let generator = TreatmentOptionGenerator(
                catalog: catalog,
                admittedCapabilities: Set(installedProfileContracts())
            )
            let set = generator.generate(
                lock: lock,
                media: currentMediaRoles(),
                intent: TreatmentIntent(
                    originalWording: command.isEmpty ? "surprise me" : command,
                    intensity: .restrained
                ),
                basePlans: candidatePlans()
            )
            treatmentOptions = set
            if set.options.isEmpty {
                noticeMessage = set.shortfallExplanation ?? "No treatment can run on this media yet."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Applies an option by adopting its validated effect plan.
    ///
    /// The command text and media are untouched, a fresh operation identity is
    /// taken so stale export state cannot be reused, and the previous treatment
    /// stays available for comparison.
    func useTreatment(_ option: TreatmentPlan) {
        errorMessage = nil
        do {
            let registryURL = try appResource(named: "registry/effects")
            let schemaURL = try appResource(named: "schemas/effect-plan.schema.json")
            let session = LocalMediaPlannerSession(
                registry: try EffectRegistry.load(from: registryURL),
                schemaValidator: try PlanSchemaValidator(schemaURL: schemaURL),
                capabilityGate: capabilityGate
            )
            let request = defaultRequest(for: option.effectPlan.effectID)
            let planned = try session.plan(
                request: request, primary: primary, outgoing: outgoing, incoming: incoming, target: target
            )
            result = planned
            previewChannels = effectChannels(for: planned)
            appliedTreatment = option
            package = nil
            exportedProject = nil
            noticeMessage = "Applied \(option.name). Your clips and timing are unchanged."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Only structural roles enter the lock. An overlay is a texture on top of
    /// a clip, not a clip in the edit, so including it would make swapping a
    /// texture look like restructuring the cut.
    private func orderedMedia() -> [LocalMediaAsset] {
        [outgoing, primary, incoming].compactMap { $0 }
    }

    private func currentMediaRoles() -> [LocalMediaRole: LocalMediaAsset] {
        var media: [LocalMediaRole: LocalMediaAsset] = [:]
        media[.primary] = primary
        media[.outgoing] = outgoing
        media[.incoming] = incoming
        media[.overlay] = overlay
        return media
    }

    private func installedProfileContracts() -> [String] {
        guard let installed = InstalledFinalCutVersionReader().read(),
              let profile = FinalCutSemanticProfileStore.profile(for: installed) else { return [] }
        return profile.admittedContracts.map(\.rawValue)
    }

    /// One validated plan per effect the current media can support.
    ///
    /// An effect that cannot be planned from this media is simply absent, which
    /// is what stops the generator offering something unrunnable.
    private func candidatePlans() -> [EffectID: EffectPlan] {
        guard let registryURL = try? appResource(named: "registry/effects"),
              let schemaURL = try? appResource(named: "schemas/effect-plan.schema.json"),
              let registry = try? EffectRegistry.load(from: registryURL),
              let validator = try? PlanSchemaValidator(schemaURL: schemaURL) else { return [:] }
        let session = LocalMediaPlannerSession(registry: registry, schemaValidator: validator, capabilityGate: capabilityGate)
        var plans: [EffectID: EffectPlan] = [:]
        for effect in EffectID.allCases {
            if let planned = try? session.plan(
                request: defaultRequest(for: effect),
                primary: primary, outgoing: outgoing, incoming: incoming, target: target
            ) {
                plans[effect] = planned.plan
            }
        }
        return plans
    }

    private func defaultRequest(for effectID: EffectID) -> String {
        switch effectID {
        case .livingStill: return "Make this a living still."
        case .targetedRotateZoom: return "Give this image a slow clockwise rotation while zooming toward the point I select."
        case .naturalDissolve: return "cross dissolve"
        case .oldTelevision: return "old television look"
        }
    }

    /// The channels a preview samples — the same ones the export would emit.
    ///
    /// Returns `nil` rather than surfacing an error: an effect with no emitter
    /// is a known gap, not a fault in the plan, and the export button already
    /// reports it with a stated reason. Failing the whole plan here would hide
    /// a valid plan behind a missing preview.
    private func effectChannels(for planned: LocalMediaPlanningResult) -> NativeFCPXMLEffectChannels? {
        var media: [LocalMediaRole: LocalMediaAsset] = [:]
        media[.primary] = primary
        media[.outgoing] = outgoing
        media[.incoming] = incoming
        media[.overlay] = overlay
        guard let emitter = StandaloneEmitterCatalog().emitter(for: planned.plan.effectID) else { return nil }
        return try? emitter.channels(plan: planned.plan, media: media)
    }

    /// Parameter controls call the same atomic revision path as other core
    /// callers. A rejected edit leaves the visible plan and preview untouched.
    func revise(parameters patch: [String: ParameterValue]) {
        guard let result else { return }
        do {
            let registryURL = try appResource(named: "registry/effects")
            let schemaURL = try appResource(named: "schemas/effect-plan.schema.json")
            let revised = try LocalMediaPlanRevisionService(
                registry: EffectRegistry.load(from: registryURL),
                schemaValidator: PlanSchemaValidator(schemaURL: schemaURL),
                capabilityGate: capabilityGate
            ).revise(result, patch: patch)
            self.result = revised
            previewChannels = effectChannels(for: revised)
            package = nil
            exportedProject = nil
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func reportValidation(_ message: String) { errorMessage = message }

    func parameterDefinitions(for result: LocalMediaPlanningResult) -> [ParameterDefinition] {
        (try? EffectRegistry.load(from: try appResource(named: "registry/effects")).definition(for: result.plan.effectID).parameters) ?? []
    }

    /// Only one package operation may be in flight. Two builds of the same plan
    /// race for one operation-ID directory, and the loser can only report that
    /// the target already exists — so overlap is prevented rather than reported.
    func savePackage() {
        guard packageTask == nil, let result, result.inertPackageDecision.allowed else { return }
        if let staleness = result.staleness(against: currentInputs) {
            invalidatePlanIfInputsDrifted()
            errorMessage = staleness.reason
            return
        }
        let inputs = currentInputs
        isSavingPackage = true
        isCancellingPackage = false
        errorMessage = nil
        let task = Task.detached(priority: .userInitiated) { () -> PackageOutcome in
            do {
                // A returned package has already been renamed into place. It is
                // a durable on-disk fact, so it is never downgraded to
                // `.cancelled` just because a cancel landed during the return.
                return .built(try LocalPlanPackageBuilder().build(result, currentInputs: inputs))
            } catch is CancellationError {
                return .cancelled
            } catch {
                return Task.isCancelled ? .cancelled : .failed(error.localizedDescription)
            }
        }
        packageTask = task
        Task { [weak self] in
            let outcome = await task.value
            self?.finishPackage(outcome)
        }
    }

    /// Generates a **new** Final Cut project from the admitted media.
    ///
    /// This is deliberately a separate action from `savePackage()`, which
    /// writes an inert payload-neutral package. Collapsing them into one
    /// button would blur the difference between "I described an operation" and
    /// "I produced something Final Cut will act on".
    ///
    /// It does not open Final Cut, read a timeline, or modify one. The user
    /// imports the result by hand, and the package says so in its own README
    /// and provenance so the claim survives being forwarded without this UI.
    func exportFinalCutProject() {
        guard !isExportingProject, let result, result.standaloneExportDecision.allowed else { return }
        if let staleness = result.staleness(against: currentInputs) {
            invalidatePlanIfInputsDrifted()
            errorMessage = staleness.reason
            return
        }

        // Built here, on the main actor, as an immutable sendable value so the
        // detached work below captures data rather than actor-isolated state.
        let ordered: [(role: LocalMediaRole, url: URL)] = LocalMediaRole.allCases.compactMap { role in
            let asset: LocalMediaAsset?
            switch role {
            case .primary: asset = primary
            case .outgoing: asset = outgoing
            case .incoming: asset = incoming
            case .overlay: asset = overlay
            }
            return asset.map { (role: role, url: $0.url) }
        }
        guard !ordered.isEmpty else {
            errorMessage = "No admitted local media to generate a project from."
            return
        }

        isExportingProject = true
        errorMessage = nil
        noticeMessage = nil
        let plan = result.plan
        let gate = capabilityGate
        let installed = installedFinalCut
        guard let exportRegistry = try? EffectRegistry.load(from: appResource(named: "registry/effects")) else {
            errorMessage = "The bundled effect registry could not be validated."
            isExportingProject = false
            return
        }

        Task { [weak self] in
            let outcome: Result<StandaloneFCPXMLExportBuilder.Package, Error> = await Task.detached(priority: .userInitiated) {
                do {
                    // Re-admit rather than reusing the assets held in memory.
                    // Evidence attests that media went through the checked
                    // path; if a file changed on disk since planning, the fresh
                    // digest will not match the plan's source identity and the
                    // gate refuses. Reusing the in-memory asset would export a
                    // project describing bytes that are no longer there.
                    let admitted = try await LocalMediaAdmission().admitAll(ordered.map(\.url))
                    var media: [LocalMediaRole: LocalMediaAsset] = [:]
                    for (index, entry) in ordered.enumerated() {
                        media[entry.role] = admitted.assets[index]
                    }
                    let builder = StandaloneFCPXMLExportBuilder(gate: gate, registry: exportRegistry)
                    return .success(try builder.export(
                        plan: plan,
                        media: media,
                        mediaEvidence: admitted.evidence,
                        installedFinalCut: installed
                    ))
                } catch {
                    return .failure(error)
                }
            }.value

            guard let self else { return }
            self.isExportingProject = false
            switch outcome {
            case .success(let package):
                self.exportedProject = package
                self.noticeMessage = "Generated a new Final Cut project at \(package.packageRoot.path). Import it by hand — nothing was modified."
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// Requests cancellation but leaves the operation owning its state. Whether
    /// the cancel beat the builder's commit point is not known until the
    /// builder returns, and until then no second save may start.
    func cancelPackage() {
        guard packageTask != nil, !isCancellingPackage else { return }
        isCancellingPackage = true
        packageTask?.cancel()
    }

    /// The single place a package operation resolves. `.cancelled` means the
    /// commit point was never reached and nothing was written; `.built` means
    /// it was, and is reported even when a cancel was already requested,
    /// because the package exists on disk either way.
    private func finishPackage(_ outcome: PackageOutcome) {
        let cancelRequested = isCancellingPackage
        packageTask = nil
        isSavingPackage = false
        isCancellingPackage = false
        switch outcome {
        case .built(let package):
            self.package = package
            if cancelRequested {
                noticeMessage = "Cancel arrived after the package was published; it is on disk at \(package.url.path)."
            }
        case .failed(let message):
            errorMessage = message
        case .cancelled:
            noticeMessage = "Package save cancelled before publish. Nothing was written."
        }
    }

    private func appResource(named relativePath: String) throws -> URL {
        let bundleResource = Bundle.main.resourceURL?.appendingPathComponent(relativePath)
        if let bundleResource, FileManager.default.fileExists(atPath: bundleResource.path) { return bundleResource }
        let development = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: development.path) else {
            throw RegistryError.directoryNotFound(bundleResource ?? development)
        }
        return development
    }
}

private struct ContentView: View {
    @StateObject private var model = AppModel()
    @State private var wantsSecondClip = false
    @State private var wantsOverlay = false

    var body: some View {
        // Scrolls because the content is taller than the window at any
        // reasonable default size, and grew again when the effect preview
        // landed. Without this it simply clips: the slider, the compare
        // button, and the fidelity badges sit below the fold with nothing to
        // indicate they exist, so the window looks broken rather than full.
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }


    // MARK: - Chrome

    /// The safety promise stays, but as a quiet pill rather than an orange
    /// all-caps banner and a paragraph. It is a standing property of the tool,
    /// not news — shouting it on every launch trains the user to skip it.
    private var header: some View {
        HStack(spacing: 10) {
            Text("FrameSmith").font(.system(size: 20, weight: .semibold))
            Text("New projects only")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(.quaternary))
                .help("FrameSmith writes a new Final Cut project from your media, which you import by hand. It never opens Final Cut, reads an existing timeline, or changes one. Source media is never modified.")
            Spacer()
            if let build = model.installedFinalCut {
                Label("Final Cut \(build.shortVersion)", systemImage: "checkmark.seal")
                    .font(.caption2).foregroundStyle(.secondary)
                    .help(model.finalCutStatus)
            } else {
                Label("No Final Cut", systemImage: "exclamationmark.triangle")
                    .font(.caption2).foregroundStyle(.orange)
                    .help(model.finalCutStatus)
            }
        }
    }

    /// Only the slots that are in play.
    ///
    /// Three permanently-empty drop zones made the window look like a form to
    /// fill in. Most work needs one clip, so the extra roles appear on request
    /// and disappear again when emptied.
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                MediaSlotView(role: .primary, media: model.primary, loading: model.loadingRole == .primary,
                              onOpen: { openPanel(for: .primary) }, onDrop: { admit($0, as: .primary) },
                              onClear: { model.clear(.primary) })
                if showsSecondClip {
                    MediaSlotView(role: .outgoing, media: model.outgoing, loading: model.loadingRole == .outgoing,
                                  onOpen: { openPanel(for: .outgoing) }, onDrop: { admit($0, as: .outgoing) },
                                  onClear: { model.clear(.outgoing); collapseIfEmpty() })
                    MediaSlotView(role: .incoming, media: model.incoming, loading: model.loadingRole == .incoming,
                                  onOpen: { openPanel(for: .incoming) }, onDrop: { admit($0, as: .incoming) },
                                  onClear: { model.clear(.incoming); collapseIfEmpty() })
                }
                if showsOverlay {
                    MediaSlotView(role: .overlay, media: model.overlay, loading: model.loadingRole == .overlay,
                                  onOpen: { openPanel(for: .overlay) }, onDrop: { admit($0, as: .overlay) },
                                  onClear: { model.clear(.overlay); collapseIfEmpty() })
                }
            }
            HStack(spacing: 14) {
                if !showsSecondClip {
                    Button { wantsSecondClip = true } label: {
                        Label("Add clips for a transition", systemImage: "plus")
                    }.buttonStyle(.borderless).font(.caption)
                }
                if !showsOverlay {
                    Button { wantsOverlay = true } label: {
                        Label("Add an overlay texture", systemImage: "plus")
                    }.buttonStyle(.borderless).font(.caption)
                }
            }
        }
    }

    private var showsSecondClip: Bool { wantsSecondClip || model.outgoing != nil || model.incoming != nil }
    private var showsOverlay: Bool { wantsOverlay || model.overlay != nil }

    private func collapseIfEmpty() {
        if model.outgoing == nil && model.incoming == nil { wantsSecondClip = false }
        if model.overlay == nil { wantsOverlay = false }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            // Placeholder rather than a paragraph: the field says what to do
            // by example, which needs no explanatory sentence above it.
            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.command)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 64)
                if model.command.isEmpty {
                    Text("Describe the look you want…")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
            .accessibilityLabel("Effect command")

            mediaSection

            if let media = model.primary ?? model.outgoing {
                TargetPicker(media: media, target: $model.target)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 10) {
                Button {
                    model.plan()
                } label: {
                    Text("Plan").frame(minWidth: 60)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])

                Button {
                    model.surpriseMe()
                } label: {
                    Label(model.isGeneratingOptions ? "Thinking…" : "Surprise Me", systemImage: "sparkles")
                }
                .disabled(model.isGeneratingOptions || (model.primary == nil && model.outgoing == nil))
                .help("Up to three different treatments. Your clips and timing stay exactly as you set them.")

                Spacer()

                if let result = model.result {
                    Button("Package") { model.savePackage() }
                        .disabled(!result.inertPackageDecision.allowed || model.isSavingPackage)
                        .help(result.inertPackageDecision.reason)
                    Button {
                        model.exportFinalCutProject()
                    } label: {
                        Label(model.isExportingProject ? "Generating…" : "Create Project", systemImage: "film")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!result.standaloneExportDecision.allowed || model.isExportingProject)
                    .help(result.standaloneExportDecision.allowed
                          ? "Writes a new Final Cut project you import by hand."
                          : result.standaloneExportDecision.reason)
                }

                if model.loadingRole != nil {
                    Button("Cancel") { model.cancelAdmission() }.buttonStyle(.borderless)
                }
                Button {
                    model.clearAll()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Clear everything")
            }

            if let set = model.treatmentOptions { TreatmentOptionsView(set: set, model: model) }

            // Only surfaced when something is actually blocked. The Final Cut
            // build and the never-modifies promise both live in the header now;
            // restating them down here every launch was noise, and noise is how
            // a genuine blocker gets missed.
            if let result = model.result, !result.standaloneExportDecision.allowed {
                Label(result.standaloneExportDecision.reason, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = model.errorMessage {
                Label(error, systemImage: "xmark.octagon")
                    .font(.caption).foregroundStyle(.red).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let notice = model.noticeMessage {
                Label(notice, systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let channels = model.previewChannels, let media = model.primary {
                EffectPreview(media: media, channels: channels)
            } else if model.result != nil {
                // A plan with no preview is a stated gap, not a blank space.
                // The export button reports the same absence with its own
                // reason; leaving nothing here would read as "no effect".
                Label("No preview for this effect yet", systemImage: "eye.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("This effect has no emitter, so nothing can be shown or generated from it.")
            }
            if let result = model.result {
                ParameterInspector(result: result, definitions: model.parameterDefinitions(for: result), revise: model.revise, reportValidation: model.reportValidation)
                PlanSummary(result: result)
            }
            if let package = model.package {
                Text("Saved inert local plan/media package: \(package.url.path). It is not importable FCPXML.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let project = model.exportedProject {
                GeneratedProjectSummary(package: project)
            }
        }
    }

    private func openPanel(for role: LocalMediaRole) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.movie, .image]
        if panel.runModal() == .OK, let url = panel.url { admit([url], as: role) }
    }

    private func admit(_ urls: [URL], as role: LocalMediaRole) {
        guard let url = urls.first else { return }
        model.admit(url, as: role)
    }
}

/// Metadata-driven inspector: it intentionally has no effect-ID switches.
private struct ParameterInspector: View {
    let result: LocalMediaPlanningResult
    let definitions: [ParameterDefinition]
    let revise: ([String: ParameterValue]) -> Void
    let reportValidation: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Creative parameters").font(.headline)
                Button("Reset all") {
                    let patch = Dictionary(uniqueKeysWithValues: definitions.compactMap { definition -> (String, ParameterValue)? in
                        (definition.presentation ?? .failClosed).exposure.isEditable ? result.baselineParameters[definition.name].map { (definition.name, $0) } : nil
                    })
                    revise(patch)
                }
            }
            ForEach(ParameterGroup.allCases, id: \.self) { group in
                let listed = definitions.filter { ($0.presentation ?? .failClosed).group == group }
                if !listed.isEmpty {
                    Text(group.rawValue.capitalized).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(listed, id: \.name) { definition in
                        ParameterControl(definition: definition, value: result.plan.parameters[definition.name] ?? .null, baseline: result.baselineParameters[definition.name], revise: revise, reportValidation: reportValidation)
                    }
                }
            }
        }
        .padding(10).background(.quaternary).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ParameterControl: View {
    let definition: ParameterDefinition
    let value: ParameterValue
    let baseline: ParameterValue?
    let revise: ([String: ParameterValue]) -> Void
    let reportValidation: (String) -> Void
    @State private var text = ""

    private var presentation: ParameterPresentation { definition.presentation ?? .failClosed }
    private var editable: Bool { presentation.exposure.isEditable }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(presentation.label)
                if presentation.exposure == .approximateEditable { Text("Approximate").font(.caption2).foregroundStyle(.orange) }
                if !editable { Text("Read-only").font(.caption2).foregroundStyle(.secondary) }
                Spacer()
                if editable, let baseline { Button("Reset") { revise([definition.name: baseline]) }.font(.caption) }
            }
            if editable { control; Text(presentation.explanation).font(.caption).foregroundStyle(.secondary) } else { Text("\(display(value)) — \(presentation.explanation)").font(.caption).foregroundStyle(.secondary) }
            if let units = presentation.units, editable { Text(units).font(.caption2).foregroundStyle(.secondary) }
        }
        .onAppear { text = display(value) }
        .onChange(of: value) { _, newValue in text = display(newValue) }
    }

    @ViewBuilder private var control: some View {
        switch definition.type {
        case "boolean":
            Toggle("", isOn: Binding(get: { if case .boolean(let flag) = value { return flag }; return false }, set: { revise([definition.name: .boolean($0)]) }))
                .labelsHidden()
        case "string" where definition.allowedValues != nil:
            Picker("", selection: Binding(get: { value.stringValue ?? "" }, set: { revise([definition.name: .string($0)]) })) {
                ForEach(definition.allowedValues?.compactMap(\.stringValue) ?? [], id: \.self) { Text($0).tag($0) }
            }.labelsHidden()
        case "integer":
            Stepper(value: Binding(get: { value.numberValue.map(Int.init) ?? 0 }, set: { revise([definition.name: .integer($0)]) }), in: Int(definition.minimum ?? -1000)...Int(definition.maximum ?? 1000)) { Text(display(value)) }
        default:
            HStack {
                if let minimum = definition.minimum, let maximum = definition.maximum {
                    Slider(value: Binding(get: { value.numberValue ?? 0 }, set: { revise([definition.name: .number($0)]) }), in: minimum...maximum)
                }
                TextField("Value", text: $text).frame(width: 72).onSubmit {
                    switch ParameterNumericInput.parse(text) {
                    case .success(let number): revise([definition.name: .number(number)])
                    case .failure(let error): reportValidation("\(presentation.label): \(error.message)")
                    }
                }
            }
        }
    }

    private func display(_ value: ParameterValue) -> String {
        switch value { case .string(let string): return string; case .number(let number): return String(number); case .integer(let integer): return String(integer); case .boolean(let boolean): return boolean ? "On" : "Off"; default: return "—" }
    }
}

private struct MediaSlotView: View {
    let role: LocalMediaRole
    let media: LocalMediaAsset?
    let loading: Bool
    let onOpen: () -> Void
    let onDrop: ([URL]) -> Void
    let onClear: () -> Void

    @State private var isTargeted = false

    private var title: String {
        switch role {
        case .primary: return "Clip"
        case .outgoing: return "From"
        case .incoming: return "To"
        case .overlay: return "Overlay"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let media {
                    SourcePreview(media: media)
                } else {
                    // An icon and one word, rather than a sentence in every box.
                    VStack(spacing: 6) {
                        Image(systemName: loading ? "hourglass" : "photo.on.rectangle.angled")
                            .font(.system(size: 22, weight: .light))
                        Text(loading ? "Reading…" : title)
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { if !loading { onOpen() } }
                }
            }
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary.opacity(isTargeted ? 0.9 : 0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isTargeted ? Color.accentColor : .clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
                guard let provider = providers.first else { return false }
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async { onDrop([url]) }
                }
                return true
            }

            if let media {
                HStack(spacing: 6) {
                    Text(media.url.lastPathComponent)
                        .font(.caption2).lineLimit(1).truncationMode(.middle)
                        // The full path and dimensions are still available,
                        // just not occupying two permanent lines per slot.
                        .help("\(media.canonicalPath)\n\(media.kind.rawValue) · \(media.dimensions.width)×\(media.dimensions.height)")
                    Spacer()
                    Button(action: onClear) { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.tertiary)
                        .help("Remove")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SourcePreview: View {
    let media: LocalMediaAsset

    var body: some View {
        switch media.kind {
        case .movie:
            VideoPlayer(player: AVPlayer(url: media.url))
        case .still:
            if let image = NSImage(contentsOf: media.url) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Text("Image unavailable")
            }
        }
    }
}

private struct TargetPicker: View {
    let media: LocalMediaAsset
    @Binding var target: Target?

    var body: some View {
        GeometryReader { proxy in
            let container = MediaSize(width: proxy.size.width, height: proxy.size.height)
            let mediaSize = MediaSize(width: Double(media.dimensions.width), height: Double(media.dimensions.height))
            ZStack {
                SourcePreview(media: media)
                if let target, let point = try? AspectFitPointMapper.viewPoint(for: target, media: mediaSize, in: container) {
                    Circle().stroke(.yellow, lineWidth: 3).frame(width: 18, height: 18).position(x: point.x, y: point.y)
                }
            }
            // Must fill the reader. `AspectFitPointMapper` computes the
            // displayed rect as *centred* in the container, but GeometryReader
            // aligns its content top-leading by default — so without this the
            // image is drawn hard left while the mapper believes it is in the
            // middle. Every click on the visible image then resolves to
            // letterbox, is rejected, and produces no target at all.
            .frame(width: container.width, height: container.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                target = try? AspectFitPointMapper.target(for: MediaPoint(x: value.location.x, y: value.location.y), media: mediaSize, in: container)
            })
        }
        .overlay(alignment: .bottom) {
            // The hint retires once it has been acted on. Leaving instructions
            // on screen forever is how a UI ends up shouting at people who
            // already know.
            if target == nil {
                Text("Click to set a focal point")
                    .font(.caption2)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(.thinMaterial))
                    .padding(.bottom, 8)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct PlanSummary: View {
    let result: LocalMediaPlanningResult

    var body: some View {
        let plan = result.plan
        VStack(alignment: .leading, spacing: 4) {
            Text("Schema \(plan.schemaVersion) local plan").font(.headline)
            Text("Effect: \(plan.effectID.rawValue) · Representation: \(plan.representation.rawValue)")
            Text("Parameters: \(plan.parameters.keys.sorted().joined(separator: ", "))")
            Text("Fallback: \(plan.fallback)")
            Text(result.localPreviewDecision.reason).foregroundStyle(.secondary)
        }
        .font(.caption)
        .textSelection(.enabled)
        .padding(10)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// What the app says after generating a project.
///
/// The claim is stated here as well as in the package's own README and
/// provenance. Saying it in one place would be enough for a user who reads the
/// package, and not enough for one who only ever sees this window.
private struct GeneratedProjectSummary: View {
    let package: StandaloneFCPXMLExportBuilder.Package

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Generated a new Final Cut project", systemImage: "checkmark.seal")
                .font(.headline)

            Text("FrameSmith wrote a new project. It did not open Final Cut, did not read an existing timeline, and did not modify one. Import it by hand.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LabeledContent("Effect") { Text(package.effectID.rawValue).textSelection(.enabled) }
            LabeledContent("Package") { Text(package.packageRoot.path).textSelection(.enabled) }
            LabeledContent("FCPXML") { Text(package.fcpxmlURL.lastPathComponent).textSelection(.enabled) }
            if let build = package.admittedAgainst {
                LabeledContent("Verified against") { Text("Final Cut \(build.description)").textSelection(.enabled) }
            }

            HStack {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([package.packageRoot])
                }
                Button("Open Import Instructions") {
                    NSWorkspace.shared.open(package.instructionsURL)
                }
            }
            .controlSize(.small)
        }
        .font(.caption)
        .padding(10)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// How much a preview can be trusted.
///
/// Stated per preview rather than assumed, because the tiers differ by more
/// than polish. A transform preview reads the exact numbers that will be
/// exported; a colour preview is a guess at a mapping nothing has observed.
/// Presenting them identically would make the second look as reliable as the
/// first.
private enum PreviewFidelity {
    /// Reads the emitted keyframes directly. Exact at keyframes.
    case exact
    /// Directionally right, magnitude unverified.
    case indicative

    var label: String {
        switch self {
        case .exact: return "Exact"
        case .indicative: return "Indicative"
        }
    }

    var color: Color {
        switch self {
        case .exact: return .green
        case .indicative: return .orange
        }
    }
}

/// Previews an effect by sampling the channels that will actually be exported.
///
/// The alternative — rendering from the composition model — would let the
/// preview and the export disagree, and only Final Cut would ever find out.
private struct EffectPreview: View {
    let media: LocalMediaAsset
    let channels: NativeFCPXMLEffectChannels

    @State private var time: Double = 0
    @State private var showColor = true
    @State private var comparing = false

    private var sampler: NativeFCPXMLChannelSampler {
        NativeFCPXMLChannelSampler(frameHeight: channels.frameHeight)
    }

    private var previewTime: Double {
        PreviewTime.clamped(time, duration: channels.durationSeconds)
    }

    private var state: NativeFCPXMLChannelState {
        sampler.state(
            transform: channels.transform,
            opacity: channels.opacity,
            atClipSeconds: previewTime,
            origin: channels.origin
        )
    }

    /// Indicative only. Final Cut's `Saturation` runs 0–100 with no observed
    /// mapping to a perceptual result, and the probes reused a captured `25`
    /// rather than deriving it. Treating it as a percentage increase gets the
    /// direction right and says nothing trustworthy about the amount.
    private var indicativeSaturation: Double {
        guard showColor, !comparing, let saturation = channels.saturation else { return 1 }
        return 1 + saturation / 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                ZStack {
                    Color.black
                    if let image = NSImage(contentsOf: media.url) {
                        // Offsets are in source pixels; scale them into the
                        // preview so the framing matches at any window size.
                        let ratio = geometry.size.height / CGFloat(channels.frameHeight)
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .saturation(indicativeSaturation)
                            .scaleEffect(comparing ? 1 : state.scale)
                            // Negated: Final Cut's positive rotation is
                            // counterclockwise (observed 2026-08-06) while
                            // SwiftUI's rotationEffect is clockwise-positive.
                            .rotationEffect(.degrees(comparing ? 0 : -state.rotationDegrees))
                            .offset(
                                x: comparing ? 0 : state.offsetX * ratio,
                                y: comparing ? 0 : state.offsetY * ratio
                            )
                            .opacity(comparing ? 1 : state.opacity)
                            .clipped()
                    } else {
                        Text("Image unavailable").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack(spacing: 10) {
                Text(String(format: "%.2fs", previewTime)).font(.caption.monospacedDigit())
                Slider(
                    value: Binding(
                        get: { previewTime },
                        set: { time = PreviewTime.clamped($0, duration: channels.durationSeconds) }
                    ),
                    in: 0...max(channels.durationSeconds, 0.01)
                )
                Text(String(format: "%.2fs", channels.durationSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                // Colour needs an explicit A/B. During the living still pass a
                // Saturation change was invisible during full-motion playback
                // and obvious the moment it was toggled — so a preview that
                // only ever shows the result fails silently for colour.
                Button(comparing ? "Showing original" : "Hold to compare") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in comparing = true }
                            .onEnded { _ in comparing = false }
                    )
                if channels.saturation != nil {
                    Toggle("Colour", isOn: $showColor)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                }
                Spacer()
            }

            fidelityNotes
        }
        .onChange(of: channels.durationSeconds) { _, duration in
            time = PreviewTime.clamped(time, duration: duration)
        }
    }

    @ViewBuilder
    private var fidelityNotes: some View {
        VStack(alignment: .leading, spacing: 3) {
            badge(.exact, "Position, scale, rotation and opacity read the exported keyframes.")
            Text("Between keyframes the preview interpolates linearly. Final Cut's default interpolation has never been observed, so mid-segment frames are approximate; the keyframes themselves are exact.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if channels.saturation != nil {
                badge(.indicative, "Colour direction only — the Saturation mapping is unobserved, so the amount shown is not trustworthy.")
            }
        }
    }

    private func badge(_ fidelity: PreviewFidelity, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(fidelity.label)
                .font(.caption2.bold())
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(fidelity.color.opacity(0.2))
                .foregroundStyle(fidelity.color)
                .clipShape(Capsule())
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Surprise Me's option cards.
///
/// The preservation promise is stated once at the top rather than repeated per
/// card, because it is a property of the whole feature: every option carries
/// the same editorial-structure fingerprint by construction.
private struct TreatmentOptionsView: View {
    let set: TreatmentOptionSet
    @ObservedObject fileprivate var model: AppModel
    @State private var showingRejected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            HStack(spacing: 8) {
                Label("Options", systemImage: "sparkles").font(.headline)
                // Stated once for the whole set, not repeated on every card:
                // it is a property of the feature, and three copies of the same
                // reassurance reads as anxiety rather than confidence.
                Text("Your clips and timing are locked")
                    .font(.caption2)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.quaternary))
                    .help("Every option preserves your clips, their order, every edit point and duration, and audio sync. Only the treatment changes.")
                Spacer()
            }

            if let shortfall = set.shortfallExplanation {
                Text(shortfall)
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(set.options) { option in
                OptionCard(option: option, isApplied: model.appliedTreatment?.id == option.id) {
                    model.useTreatment(option)
                }
            }

            if !set.rejected.isEmpty {
                DisclosureGroup(isExpanded: $showingRejected) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(set.rejected.enumerated()), id: \.offset) { _, entry in
                            Text(entry.explanation)
                                .font(.caption2).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Text("\(set.rejected.count) not shown").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// One option. Name, one line, and the two badges that actually change a
/// decision — everything else is a tooltip.
private struct OptionCard: View {
    let option: TreatmentPlan
    let isApplied: Bool
    let use: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(option.name).font(.system(size: 13, weight: .semibold))
                    if option.previewFidelity == .indicative {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2).foregroundStyle(.orange)
                            .help("Preview shows direction only — the exact strength is not verified.")
                    }
                    if option.editability == .framesmithRegeneration {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2).foregroundStyle(.secondary)
                            .help("Adjust by regenerating in FrameSmith rather than in Final Cut.")
                    }
                }
                Text(option.idea)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if isApplied {
                Label("Applied", systemImage: "checkmark")
                    .font(.caption2).foregroundStyle(.green)
            } else {
                Button("Use", action: use)
                    .controlSize(.small)
                    .opacity(hovering ? 1 : 0.75)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary.opacity(hovering || isApplied ? 0.5 : 0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isApplied ? Color.green.opacity(0.5) : .clear, lineWidth: 1)
        )
        .onHover { hovering = $0 }
        // The detail that used to be printed on the card is here instead, so
        // it is one hover away rather than permanently in the way.
        .help(detail)
    }

    private var detail: String {
        var lines = option.changes
        lines.append("Preserved: " + option.preserved.joined(separator: " · "))
        lines.append("Technique: " + option.techniqueCardIDs.joined(separator: ", "))
        return lines.joined(separator: "\n")
    }
}
