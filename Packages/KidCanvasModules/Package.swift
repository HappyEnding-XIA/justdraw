// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KidCanvasModules",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "KCCommon", targets: ["KCCommon"]),
        .library(name: "KCDomain", targets: ["KCDomain"]),
        .library(name: "KCDrawingEngine", targets: ["KCDrawingEngine"]),
        .library(name: "KCContentCatalog", targets: ["KCContentCatalog"]),
        .library(name: "KCSessionPersistence", targets: ["KCSessionPersistence"]),
    ],
    targets: [
        .target(
            name: "KCCommon",
            path: "Sources/KCCommon"
        ),
        .target(
            name: "KCDomain",
            dependencies: ["KCCommon"],
            path: "Sources/KCDomain"
        ),
        .target(
            name: "KCDrawingEngine",
            dependencies: ["KCCommon", "KCDomain"],
            path: "Sources/KCDrawingEngine"
        ),
        .target(
            name: "KCContentCatalog",
            dependencies: ["KCCommon", "KCDomain"],
            path: "Sources/KCContentCatalog",
            resources: [.process("Resources")]
        ),
        .target(
            name: "KCSessionPersistence",
            dependencies: ["KCCommon", "KCDomain"],
            path: "Sources/KCSessionPersistence"
        ),
        .testTarget(
            name: "KCCommonTests",
            dependencies: ["KCCommon"],
            path: "Tests/KCCommonTests"
        ),
        .testTarget(
            name: "KCDomainTests",
            dependencies: ["KCDomain"],
            path: "Tests/KCDomainTests"
        ),
        .testTarget(
            name: "KCDrawingEngineTests",
            dependencies: ["KCDrawingEngine"],
            path: "Tests/KCDrawingEngineTests"
        ),
        .testTarget(
            name: "KCContentCatalogTests",
            dependencies: ["KCContentCatalog"],
            path: "Tests/KCContentCatalogTests"
        ),
        .testTarget(
            name: "KCSessionPersistenceTests",
            dependencies: ["KCSessionPersistence"],
            path: "Tests/KCSessionPersistenceTests"
        ),
    ]
)
