// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FCPCommandConsole",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FCPCommandConsoleCore", targets: ["FCPCommandConsoleCore"]),
        .executable(name: "fcpcommandconsole", targets: ["FCPCommandConsole"])
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
        .testTarget(
            name: "FCPCommandConsoleTests",
            dependencies: ["FCPCommandConsoleCore"],
            path: "Tests/FCPCommandConsoleTests"
        )
    ]
)
