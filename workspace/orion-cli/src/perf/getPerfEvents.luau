local json = require("@std/json")

local types = require("@root/perf/types")

local SIDES = { "base", "head" }

local function median(values: { number }): number
	local sorted = table.clone(values)
	table.sort(sorted)

	local middle = #sorted // 2 + 1

	return if #sorted % 2 == 1 then sorted[middle] else (sorted[middle - 1] + sorted[middle]) / 2
end

local function getNumbers(value: json.Value): { number }
	local numbers = {}

	for _, item in json.asArray(value) or {} do
		if type(item) == "number" then
			table.insert(numbers, item)
		end
	end

	return numbers
end

local function addBench(properties: json.Object, bench: json.Object): number
	local count = 0

	for name, rounds in bench do
		local values = getNumbers(rounds)

		if #values > 0 then
			properties[`bench.{name}`] = median(values)
			count += 1
		end
	end

	return count
end

-- Each story holds one sample per run, keyed by interaction and then by
-- measurement.
local function addRender(properties: json.Object, render: json.Object): number
	local count = 0

	for story, runs in render do
		local collected: { [string]: { number } } = {}

		for _, run in json.asArray(runs) or {} do
			for interaction, sample in json.asObject(run) or {} do
				for measurement, value in json.asObject(sample) or {} do
					if type(value) == "number" then
						local key = `{story}.{interaction}.{measurement}`
						collected[key] = collected[key] or {}
						table.insert(collected[key], value)
					end
				end
			end
		end

		for key, values in collected do
			properties[key] = median(values)
			count += 1
		end
	end

	return count
end

--[[
	Turns the perf harness's raw.json into one `perf_run` event per side. Each
	event carries the median of every benchmark (`bench.<name>`) and every story
	measurement (`<story>.<interaction>.<measurement>`) across the run's rounds,
	along with the side's commit and where the run happened. A side with no
	measurements sends nothing.
]]
return function(raw: json.Object, context: types.RunContext): { types.PerfEvent }
	local bench = json.asObject(raw.bench)
	local render = json.asObject(raw.render)
	local events = {}

	for _, side in SIDES do
		local revision = json.asObject(raw[side]) or json.object({})
		local properties = json.object({
			side = side,
			sha = revision.sha,
			ref = revision.ref,
			event_name = context.eventName,
			pull_request = context.pullRequest,
			runner = context.runner,
			run_url = context.runUrl,
		})

		local count = 0
		local benchSide = bench and json.asObject(bench[side])
		local renderSide = render and json.asObject(render[side])

		if benchSide then
			count += addBench(properties, benchSide)
		end

		if renderSide then
			count += addRender(properties, renderSide)
		end

		if count > 0 then
			table.insert(events, { event = "perf_run", properties = properties })
		end
	end

	return events
end
