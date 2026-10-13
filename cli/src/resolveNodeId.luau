local graph = require("@root/graph")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- Turns what a command was given into a node id. An id that exists is used as it is. Otherwise a label names a group
-- when exactly one group has it, ignoring case. Several groups sharing a label fail and list their ids to choose from.
-- A value that names nothing comes back unchanged, so the command reports the missing id as it always has.
local function resolveNodeId(doc: Doc, value: string): string
	if graph.find(doc, value) then
		return value
	end

	local wanted = value:lower()
	local matches: { Item } = {}

	for _, node in doc.nodes do
		if graph.isGroup(node) and graph.label(node):lower() == wanted then
			table.insert(matches, node)
		end
	end

	if #matches == 0 then
		return value
	end

	if #matches == 1 then
		return matches[1].id
	end

	local choices = {}

	for _, match in matches do
		table.insert(choices, `{match.id} ({graph.label(match)})`)
	end

	error(`"{value}" is the label of {#matches} groups; use one of their ids: {table.concat(choices, ", ")}`, 0)
end

return resolveNodeId
