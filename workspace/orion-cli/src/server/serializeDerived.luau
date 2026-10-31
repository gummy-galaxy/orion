local json = require("@std/json")

local graphTypes = require("@root/canvas/types")

type Derived = graphTypes.Derived
type GroupStats = graphTypes.GroupStats

local function copyValues<T>(values: { [string]: T }): json.Object
	local object = json.object({})

	for key, value in values do
		object[key] = value :: json.Value
	end

	return object
end

local function serializeStats(stats: GroupStats): json.Object
	return json.object({
		total = stats.total,
		done = stats.done,
		ready = stats.ready,
		blocked = stats.blocked,
		outside = stats.outside,
	})
end

-- Derived values are sent beside the document, keyed by item id. They are never
-- written to the data file.
local function serializeDerived(derived: Derived): json.Object
	local groups = json.object({})

	for id, stats in derived.groups do
		groups[id] = serializeStats(stats)
	end

	local pulls = json.object({})

	for id, facts in derived.pulls do
		local snoozed: json.Array = {}

		for _, job in facts.snoozed do
			local value = json.object({ name = job.name })
			value["until"] = job.untilTime
			table.insert(snoozed, value)
		end

		local value = json.object({ snoozed = snoozed })
		value.readiness = facts.readiness
		value.checks = facts.checks
		value.wakesAt = facts.wakesAt
		pulls[id] = value
	end

	return json.object({
		status = copyValues(derived.status),
		flow = copyValues(derived.flow),
		leverage = copyValues(derived.leverage),
		upstream = copyValues(derived.upstream),
		rarity = copyValues(derived.rarity),
		groups = groups,
		canvas = serializeStats(derived.canvas),
		snoozed = copyValues(derived.snoozed),
		attention = copyValues(derived.attention),
		pulls = pulls,
	})
end

return serializeDerived
