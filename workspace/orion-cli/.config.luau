return {
	luau = {
		languagemode = "strict",
		aliases = {
			lute = "~/.lute/typedefs/1.0.1/lute",
			std = "~/.lute/typedefs/1.0.1/std",
			pkg = "./packages",
			root = "./src",
			batteries = "@pkg/lute@v1.0.1-nightly.20260924/batteries",
			repo = "./",
		},
	},
	lute = {
		lint = {
			rulepaths = { "../../.lute/lints" },
		},
	},
}
