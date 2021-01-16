// swift-tools-version:5.0

import PackageDescription

let package = Package(
	name: "CoreSwiftVISA",
	products: [
		.library(
			name: "CoreSwiftVISA",
			targets: ["CoreSwiftVISA"]),
	],
	targets: [
		.target(
			name: "CoreSwiftVISA",
			dependencies: []),
		.testTarget(
			name: "CoreSwiftVISATests",
			dependencies: ["CoreSwiftVISA"]),
	],
	// TODO: Can we target lower versions of Swift?
	swiftLanguageVersions: [.v5]
)
