--[[
	The selectors an id argument takes in place of an id, as data. resolveId
	reads which ones exist from here, and `lute run docs` writes the reference
	page from it. Every example has to resolve; the spec checks.
]]

export type Selector = {
	name: string,
	form: string,
	help: string,
	examples: { string },
}

local SELECTORS: { Selector } = {
	{
		name = "label",
		form = "label:<text>",
		help = "The node whose label is exactly this text. Quote it with \" or ' when it has spaces, so the shell keeps it whole.",
		examples = { 'label:"Extract slider"', "label:'Extract slider'" },
	},
	{
		name = "ref",
		form = "ref:<key or ref>",
		help = "The node with this ref. A bare key such as `owner/name#12` or `ABC-12` matches as it's stored, ignoring case, and a URL or `source:key` resolves the way `--ref` does first.",
		examples = { "ref:gummy-galaxy/orion#86", "ref:https://github.com/gummy-galaxy/orion/pull/86", "ref:jira:ABC-12" },
	},
	{
		name = "pr",
		form = "pr:<number>",
		help = "The card whose pull request has this number, with or without `#`. A value that isn't a number matches as `ref:` does.",
		examples = { "pr:86", "pr:#86" },
	},
}

local selectorsByName: { [string]: Selector } = {}

for _, selector in SELECTORS do
	selectorsByName[selector.name] = selector
end

return table.freeze({
	list = table.freeze(SELECTORS),
	byName = table.freeze(selectorsByName),
})
