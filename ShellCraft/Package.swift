// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShellCraft",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ShellCraftCore",
            targets: ["ShellCraftCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-nio-ssh.git", from: "0.8.0"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "ShellCraftCore",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOSSH", package: "swift-nio-ssh"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "ShellCraft",
            exclude: ["App/ShellCraftApp.swift"]
        ),
        .testTarget(
            name: "ShellCraftTests",
            dependencies: ["ShellCraftCore"],
            path: "ShellCraftTests"
        )
    ]
)
