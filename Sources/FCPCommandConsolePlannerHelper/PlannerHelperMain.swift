import Foundation
import FCPCommandConsoleCore

@main
struct FCPCommandConsolePlannerHelperMain {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.isEmpty else {
            write(.failure(PlannerHelperError(code: .invalidArguments)))
            return
        }

        guard let root = bundledResourceRoot() else {
            write(.failure(PlannerHelperError(code: .resourceMissing)))
            return
        }
        let engine: PlannerHelperEngine
        do {
            engine = try PlannerHelperEngine(resources: PlannerHelperResources(rootURL: root))
        } catch let error as PlannerHelperResourceError {
            let code: PlannerHelperErrorCode
            switch error {
            case .resourceMissing: code = .resourceMissing
            case .resourceTampered: code = .resourceTampered
            case .registryInvalid: code = .registryInvalid
            case .schemaInvalid: code = .schemaInvalid
            }
            write(.failure(PlannerHelperError(code: code)))
            return
        } catch {
            write(.failure(PlannerHelperError(code: .internalError)))
            return
        }

        switch PlannerHelperEngine.readStdin() {
        case .success(let data): write(engine.handle(data: data))
        case .failure: write(.failure(PlannerHelperError(code: .internalError)))
        }
    }

    private static func bundledResourceRoot() -> URL? {
        guard let bundleRoot = Bundle.module.resourceURL else { return nil }
        let candidates = [
            bundleRoot.appendingPathComponent("Resources", isDirectory: true),
            bundleRoot
        ]
        return candidates.first {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("registry/effects", isDirectory: true).path) &&
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("schemas/effect-plan.schema.json").path)
        }
    }

    private static func write(_ response: PlannerHelperResponseEnvelope) {
        guard let data = try? PlannerHelperWireCodec.encode(response) else { return }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0a]))
    }
}
