local operationTypes = require("@root/canvas/operations/types")
local types = require("@root/types")

type Changes = operationTypes.Changes

local function describeLink(sign: string, link: types.Link): string
	local label = if link.label then ` "{link.label}"` else ""
	return `  {sign} link {link.from} → {link.to} ({link.kind}){label}`
end

-- What an edit changed, one indented line each, for a write's text output. +
-- adds, ~ changes, and - removes.
local function describeChanges(changes: Changes): { string }
	local lines: { string } = {}

	for _, id in changes.added do
		table.insert(lines, `  + item {id}`)
	end

	for _, id in changes.changed do
		table.insert(lines, `  ~ item {id}`)
	end

	for _, id in changes.removed do
		table.insert(lines, `  - item {id}`)
	end

	for _, link in changes.linked do
		table.insert(lines, describeLink("+", link))
	end

	for _, link in changes.relinked do
		table.insert(lines, describeLink("~", link))
	end

	for _, link in changes.unlinked do
		table.insert(lines, describeLink("-", link))
	end

	for _, ref in changes.attached do
		table.insert(lines, `  + ref {ref.key} on {ref.id}`)
	end

	for _, ref in changes.detached do
		table.insert(lines, `  - ref {ref.key} on {ref.id}`)
	end

	return lines
end

return describeChanges
