return {
	package = {
		name = "orion",
		version = "0.1.0",
		dependencies = {
			["lute"] = {
				rev = "v1.0.1-nightly.20260924",
				sourceKind = "github",
				source = "https://github.com/luau-lang/lute",
			},
			["Archivist"] = {
				rev = "v0.2.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/archivist",
			},
			["FlipbookBatteries"] = {
				rev = "v0.12.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/flipbook-batteries",
			},
		},
		dev_dependencies = {},
	},
}
