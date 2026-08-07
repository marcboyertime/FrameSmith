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
                .frame(minWidth: 900, minHeight: 680)
        }
    }
}

@MainActor
private final class AppModel: ObservableObject {
    @Published var command = "" { didSet { invalidatePlanIfInputsDrifted() } }
    @Published var primary: LocalMediaAsset? { didSet { invalidatePlanIfInputsDrifted() } }
    @Published var outgoing: LocalMediaAsset? { didSet { invalidatePlanIfInputsDrifted() } }
    @Published var incoming: LocalMediaAsset? { didSet { invalidatePlanIfInputsDrifted() } }
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
        let emitters: [any StandaloneEffectEmitter] = [
            LivingStillStandaloneEmitter(),
            TargetedRotateZoomStandaloneEmitter()
        ]
        guard let emitter = emitters.first(where: { $0.effectID == planned.plan.effectID }) else { return nil }
        return try? emitter.channels(plan: planned.plan, media: media)
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
                    let builder = StandaloneFCPXMLExportBuilder(gate: gate)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // This banner said "Final Cut export and editability are
            // unverified" and "previews do not render an effect" until
            // 2026-08-06. Both were true when written and neither is now, so
            // it was understating the tool as badly as an overclaim would have
            // overstated it. It states what is actually true instead.
            Text("GENERATES NEW PROJECTS — NEVER MODIFIES YOUR TIMELINE")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("FrameSmith writes a new Final Cut project from your media, which you import by hand. It never opens Final Cut, reads an existing timeline, or changes one. Source media is never modified.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $model.command)
                .font(.body)
                .frame(height: 78)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                .accessibilityLabel("Effect command")

            HStack(alignment: .top, spacing: 12) {
                MediaSlotView(role: .primary, media: model.primary, loading: model.loadingRole == .primary, onOpen: { openPanel(for: .primary) }, onDrop: { urls in admit(urls, as: .primary) }, onClear: { model.clear(.primary) })
                MediaSlotView(role: .outgoing, media: model.outgoing, loading: model.loadingRole == .outgoing, onOpen: { openPanel(for: .outgoing) }, onDrop: { urls in admit(urls, as: .outgoing) }, onClear: { model.clear(.outgoing) })
                MediaSlotView(role: .incoming, media: model.incoming, loading: model.loadingRole == .incoming, onOpen: { openPanel(for: .incoming) }, onDrop: { urls in admit(urls, as: .incoming) }, onClear: { model.clear(.incoming) })
            }

            if let media = model.primary ?? model.outgoing {
                TargetPicker(media: media, target: $model.target)
                    .frame(height: 220)
            }

            HStack {
                Button("Plan") { model.plan() }
                    .keyboardShortcut(.return, modifiers: [.command])
                Button("Clear") { model.clearAll() }
                if model.loadingRole != nil {
                    Button("Cancel") { model.cancelAdmission() }
                }
                if model.isSavingPackage {
                    Button(model.isCancellingPackage ? "Cancelling…" : "Cancel Save") { model.cancelPackage() }
                        .disabled(model.isCancellingPackage)
                }
                if let result = model.result {
                    Button(model.isSavingPackage ? "Saving Local Package…" : "Save Local Plan Package") { model.savePackage() }
                        .disabled(!result.inertPackageDecision.allowed || model.isSavingPackage)
                        .help(result.inertPackageDecision.reason)
                }
                if let result = model.result {
                    let standalone = result.standaloneExportDecision
                    Button(model.isExportingProject ? "Generating…" : "Generate Final Cut Project…") {
                        model.exportFinalCutProject()
                    }
                    .disabled(!standalone.allowed || model.isExportingProject)
                    .help(standalone.allowed
                          ? "Writes a new Final Cut project you import by hand. Nothing existing is opened or changed."
                          : standalone.reason)
                }
            }

            // The two Final Cut claims, kept visually apart because they are
            // different claims and not two grades of the same one. Generating a
            // new project is something the app can do; modifying a timeline it
            // has never seen is not, and never will be from local media alone.
            VStack(alignment: .leading, spacing: 4) {
                Text(model.finalCutStatus)
                    .font(.caption)
                    .foregroundStyle(model.installedFinalCut == nil ? .orange : .secondary)
                if let result = model.result {
                    if !result.standaloneExportDecision.allowed {
                        Label(result.standaloneExportDecision.reason, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .textSelection(.enabled)
                    }
                    Text("Modifying an existing timeline is unavailable: \(result.fcpxmlExportDecision.reason)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            if let error = model.errorMessage {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
            }
            if let notice = model.noticeMessage {
                Text(notice).foregroundStyle(.orange).textSelection(.enabled)
            }
            if let channels = model.previewChannels, let media = model.primary {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Effect preview").font(.headline)
                    EffectPreview(media: media, channels: channels)
                }
            } else if model.result != nil {
                // A plan with no preview is a stated gap, not a blank space.
                // The export button reports the same absence with its own
                // reason; leaving nothing here would read as "no effect".
                Text("No preview for this effect yet — it has no emitter, so nothing can be shown or generated from it.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let result = model.result {
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
            Spacer(minLength: 0)
        }
        .padding()
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

private struct MediaSlotView: View {
    let role: LocalMediaRole
    let media: LocalMediaAsset?
    let loading: Bool
    let onOpen: () -> Void
    let onDrop: ([URL]) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(role.rawValue.uppercased()).font(.caption.weight(.semibold))
            Group {
                if let media {
                    SourcePreview(media: media)
                } else {
                    Text("Drop a local movie or still here")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 130)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
                guard let provider = providers.first else { return false }
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async { onDrop([url]) }
                }
                return true
            }
            if let media {
                Text("\(media.kind.rawValue) · \(media.dimensions.width)×\(media.dimensions.height)")
                    .font(.caption)
                Text(media.canonicalPath).font(.caption2).lineLimit(1).truncationMode(.middle)
                Button("Remove", action: onClear).font(.caption)
            } else {
                Button(loading ? "Reading…" : "Open…", action: onOpen).disabled(loading)
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
        .overlay(alignment: .topLeading) {
            Text("Optional target point — letterbox clicks are rejected").font(.caption).padding(5).background(.thinMaterial)
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
            Text("Editable: \(plan.editableProperties.map(\.name).joined(separator: ", "))")
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

    private var state: NativeFCPXMLChannelState {
        sampler.state(
            transform: channels.transform,
            opacity: channels.opacity,
            atClipSeconds: time,
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
                Text(String(format: "%.2fs", time)).font(.caption.monospacedDigit())
                Slider(value: $time, in: 0...max(channels.durationSeconds, 0.01))
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
