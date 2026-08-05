// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FCPCommandConsole",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FCPCommandConsoleCore", targets: ["FCPCommandConsoleCore"]),
        .executable(name: "fcpcommandconsole", targets: ["FCPCommandConsole"]),
        .executable(name: "FCPCommandConsoleApp", targets: ["FCPCommandConsoleApp"]),
        .executable(name: "fcpcommandconsole-planner-helper", targets: ["FCPCommandConsolePlannerHelper"]),
        .executable(name: "fcpcommandconsole-roundtrip-spike", targets: ["FCPCommandConsoleRoundTripSpike"]),
        .executable(name: "fcpcommandconsole-living-still-probe", targets: ["FCPCommandConsoleLivingStillProbe"])
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
            name: "FCPCommandConsoleApp",
            dependencies: ["FCPCommandConsoleCore"],
            path: "Sources/FCPCommandConsoleApp"
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
        .executableTarget(
            name: "FCPCommandConsoleLivingStillProbe",
            dependencies: ["FCPCommandConsoleCore"],
            path: "Sources/FCPCommandConsoleLivingStillProbe"
        ),
        .testTarget(
            name: "FCPCommandConsoleTests",
            dependencies: ["FCPCommandConsoleCore", "FCPCommandConsoleRoundTripSpike"],
            path: "Tests/FCPCommandConsoleTests"
        )
    ]
)
