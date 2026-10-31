local json = require("@std/json")

local operationTypes = require("@root/canvas/operations/types")
local types = require("@root/types")

type Changes = operationTypes.Changes
type RefChange = operationTypes.RefChange

local function serializeIds(ids: { string }): json.Array
	return table.clone(ids) :: json.Array
end

local function serializeLinks(links: { types.Link }): json.Array
	local values: json.Array = {}

	for _, link in links do
		local value = json.object({ from = link.from, to = link.to, kind = link.kind })
		value.label = link.label
		table.insert(values, value)
	end

	return values
end

local function serializeRefs(refs: { RefChange }): json.Array
	local values: json.Array = {}

	for _, ref in refs do
		table.insert(values, json.object({ id = ref.id, source = ref.source, kind = ref.kind, key = ref.key }))
	end

	return values
end

-- What an edit changed, as the `changes` field of a write's JSON output.
local function serializeChanges(changes: Changes): json.Object
	return json.object({
		items = json.object({
			added = serializeIds(changes.added),
			changed = serializeIds(changes.changed),
			removed = serializeIds(changes.removed),
		}),
		links = json.object({
			added = serializeLinks(changes.linked),
			changed = serializeLinks(changes.relinked),
			removed = serializeLinks(changes.unlinked),
		}),
		refs = json.object({
			attached = serializeRefs(changes.attached),
			detached = serializeRefs(changes.detached),
		}),
	})
end

return serializeChanges
