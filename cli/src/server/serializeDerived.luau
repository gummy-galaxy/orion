local json = require("@std/json")

local graph = require("@root/graph")

type Derived = graph.Derived

local function copyValues<T>(values: { [string]: T }): json.Object
	local object = json.object({})

	for key, value in values do
		object[key] = value :: json.Value
	end

	return object
end

-- Derived values are sent beside the document, keyed by item id. They are never written to the data file.
local function serializeDerived(derived: Derived): json.Object
	local groups = json.object({})

	for id, stats in derived.groups do
		groups[id] = json.object({
			total = stats.total,
			done = stats.done,
			ready = stats.ready,
			blocked = stats.blocked,
			outside = stats.outside,
		})
	end

	return json.object({
		status = copyValues(derived.status),
		flow = copyValues(derived.flow),
		leverage = copyValues(derived.leverage),
		upstream = copyValues(derived.upstream),
		rarity = copyValues(derived.rarity),
		groups = groups,
	})
end

return serializeDerived
