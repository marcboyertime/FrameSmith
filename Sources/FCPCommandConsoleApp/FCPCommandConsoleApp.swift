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
        do {
            let registryURL = try appResource(named: "registry/effects")
            let schemaURL = try appResource(named: "schemas/effect-plan.schema.json")
            let session = LocalMediaPlannerSession(
                registry: try EffectRegistry.load(from: registryURL),
                schemaValidator: try PlanSchemaValidator(schemaURL: schemaURL)
            )
            result = try session.plan(request: command, primary: primary, outgoing: outgoing, incoming: incoming, target: target)
        } catch {
            errorMessage = error.localizedDescription
        }
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
            Text("LOCAL MEDIA PREVIEW ONLY")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("Final Cut export and editability are unverified. Source previews do not render an effect or modify source media.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
                    let export = result.fcpxmlExportDecision
                    Button("FCPXML Export") {}
                        .disabled(true)
                        .help(export.reason)
                    Text(export.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button("FCPXML Export") {}
                        .disabled(true)
                        .help("Plan a local selection first; Final Cut export remains unverified.")
                }
            }

            if let error = model.errorMessage {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
            }
            if let notice = model.noticeMessage {
                Text(notice).foregroundStyle(.orange).textSelection(.enabled)
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
