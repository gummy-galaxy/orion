return {
	luau = {
		languagemode = "strict",
		aliases = {
			lute = "~/.lute/typedefs/1.0.1/lute",
			std = "~/.lute/typedefs/1.0.1/std",
			pkg = "./packages",
			root = "./src",
			batteries = "@pkg/lute@v1.0.1-nightly.20260924/batteries",
			archivist = "@pkg/Archivist@v0.2.0",
			repo = "./",
		},
	},
	lute = {
		lint = {
			rulepaths = { "./lints" },
		},
	},
}
