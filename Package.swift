// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AristarCodexGUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AristarCodexGUI",
            targets: ["AristarCodexGUI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AristarCodexGUI",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/AristarCodexGUI"
        )
    ]
)
