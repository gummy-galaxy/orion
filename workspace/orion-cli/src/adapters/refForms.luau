--[[
	The forms `--ref` takes, as data, in the order resolveRef tries them. `lute run docs` writes the reference page
	from it. Every example has to resolve to its key with the adapter it names; the spec checks.
]]

export type RefForm = {
	form: string,
	help: string,
	-- The source kind whose adapter parses the form, or nil for the branch form resolveRef parses itself.
	kind: string?,
	-- The sources the form needs configured to resolve, as a sentence.
	needs: string?,
	example: string,
	-- The key the example resolves to, which `--where 'ref = "…"'` and `ref:` selectors match.
	key: string,
}

local REF_FORMS: { RefForm } = {
	{
		form = "https://github.com/<owner>/<name>/pull/<number>",
		help = "A GitHub pull request.",
		kind = "github",
		example = "https://github.com/vocksel/orion/pull/86",
		key = "vocksel/orion#86",
	},
	{
		form = "https://github.com/<owner>/<name>/issues/<number>",
		help = "A GitHub issue.",
		kind = "github",
		example = "https://github.com/vocksel/orion/issues/146",
		key = "vocksel/orion#146",
	},
	{
		form = "https://<host>/<owner>/<name>/pull/<number>",
		help = "A pull request on GitHub Enterprise, or an issue with `/issues/`. Its key starts with the host.",
		kind = "github",
		needs = "Needs a GitHub source for the host.",
		example = "https://github.example.com/owner/name/pull/12",
		key = "github.example.com/owner/name#12",
	},
	{
		form = "<browse URL>/<KEY>",
		help = "A Jira issue, by its URL.",
		kind = "jira",
		needs = "Needs a Jira source whose browse URL starts the link.",
		example = "https://jira.example.com/browse/ABC-12",
		key = "ABC-12",
	},
	{
		form = "<source>:<KEY>",
		help = "A Jira issue, by its key and the id of the source it belongs to.",
		kind = "jira",
		needs = "Needs a Jira source with that id.",
		example = "jira:ABC-12",
		key = "ABC-12",
	},
	{
		form = "branch:<owner>/<name>@<branch>",
		help = "The branch work started on, keyed the way hop keys branches. The first `@` ends the repository.",
		example = "branch:vocksel/orion@agent/196-attach",
		key = "vocksel/orion@agent/196-attach",
	},
	{
		form = "branch:<host>/<owner>/<name>@<branch>",
		help = "A branch on GitHub Enterprise.",
		needs = "Needs a GitHub source for the host.",
		example = "branch:github.example.com/owner/name@feature",
		key = "github.example.com/owner/name@feature",
	},
}

return table.freeze(REF_FORMS)
