// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FCPCommandConsole",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FCPCommandConsoleCore", targets: ["FCPCommandConsoleCore"]),
        .executable(name: "fcpcommandconsole", targets: ["FCPCommandConsole"]),
        .executable(name: "fcpcommandconsole-planner-helper", targets: ["FCPCommandConsolePlannerHelper"]),
        .executable(name: "fcpcommandconsole-roundtrip-spike", targets: ["FCPCommandConsoleRoundTripSpike"])
    ],
    targets: [
        .target(
            name: "FCPCommandConsoleCore",
            path: "service"
        ),
        .executableTarget(
            name: "FCPCommandConsole",
            dependencies: ["FCPCommandConsoleCore"],
            path: "Sources/FCPCommandConsole"
        ),
        .executableTarget(
            name: "FCPCommandConsolePlannerHelper",
            dependencies: ["FCPCommandConsoleCore"],
            path: "Sources/FCPCommandConsolePlannerHelper",
            resources: [.copy("Resources")]
        ),
        .executableTarget(
            name: "FCPCommandConsoleRoundTripSpike",
            dependencies: ["FCPCommandConsoleCore"],
            path: "Sources/FCPCommandConsoleRoundTripSpike"
        ),
        .testTarget(
            name: "FCPCommandConsoleTests",
            dependencies: ["FCPCommandConsoleCore", "FCPCommandConsoleRoundTripSpike"],
            path: "Tests/FCPCommandConsoleTests"
        )
    ]
)
