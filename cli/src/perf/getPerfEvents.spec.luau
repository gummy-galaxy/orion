local json = require("@std/json")
local test = require("@std/test")

local getPerfEvents = require("@root/perf/getPerfEvents")
local types = require("@root/perf/types")

local CONTEXT: types.RunContext = {
	eventName = "push",
	pullRequest = nil,
	runner = "artemis",
	runUrl = "https://github.com/vocksel/orion/actions/runs/1",
}

local function raw(source: string): json.Object
	return json.asObject(json.deserialize(source) :: json.Value) :: json.Object
end

test.case("getPerfEvents sends one event per side with medians across rounds", function(assert)
	local events = getPerfEvents(
		raw([[{
			"base": { "ref": "HEAD^1", "sha": "aaa" },
			"head": { "ref": "main", "sha": "bbb" },
			"bench": {
				"rounds": 3,
				"base": { "derive": [3, 1, 2] },
				"head": { "derive": [4, 1, 3, 2] }
			},
			"render": {
				"base": {
					"perf--canvas": [
						{ "pan": { "layoutMs": 10, "slowFrames": 2 } },
						{ "pan": { "layoutMs": 30, "slowFrames": 0 } },
						{ "pan": { "layoutMs": 20, "slowFrames": 1 } }
					]
				},
				"head": {
					"perf--canvas": [
						{ "pan": { "layoutMs": 8 } }
					]
				}
			}
		}]]),
		CONTEXT
	)

	assert.eq(#events, 2)

	local base = events[1].properties
	assert.eq(events[1].event, "perf_run")
	assert.eq(base.side, "base")
	assert.eq(base.sha, "aaa")
	assert.eq(base.ref, "HEAD^1")
	assert.eq(base["bench.derive"], 2)
	assert.eq(base["perf--canvas.pan.layoutMs"], 20)
	assert.eq(base["perf--canvas.pan.slowFrames"], 1)

	local head = events[2].properties
	assert.eq(head.side, "head")
	assert.eq(head.sha, "bbb")
	assert.eq(head["bench.derive"], 2.5)
	assert.eq(head["perf--canvas.pan.layoutMs"], 8)
end)

test.case("getPerfEvents records where the run happened", function(assert)
	local events = getPerfEvents(
		raw([[{ "head": { "ref": "feature", "sha": "ccc" }, "bench": { "head": { "derive": [1] } } }]]),
		{ eventName = "pull_request", pullRequest = 42, runner = "artemis", runUrl = "https://example.com/run" }
	)

	local properties = events[1].properties
	assert.eq(properties.event_name, "pull_request")
	assert.eq(properties.pull_request, 42)
	assert.eq(properties.runner, "artemis")
	assert.eq(properties.run_url, "https://example.com/run")
end)

test.case("getPerfEvents skips sides without measurements", function(assert)
	local events = getPerfEvents(
		raw([[{
			"base": { "ref": "HEAD^1", "sha": "aaa" },
			"head": { "ref": "main", "sha": "bbb" },
			"bench": { "base": {}, "head": { "derive": [1] } },
			"render": { "base": { "perf--canvas": [] } }
		}]]),
		CONTEXT
	)

	assert.eq(#events, 1)
	assert.eq(events[1].properties.side, "head")
end)

test.case("getPerfEvents ignores values that aren't numbers", function(assert)
	local events = getPerfEvents(
		raw([[{
			"head": { "sha": "bbb" },
			"bench": { "head": { "derive": ["slow", 5] } },
			"render": { "head": { "perf--canvas": [{ "pan": { "layoutMs": "n/a" } }] } }
		}]]),
		CONTEXT
	)

	local properties = events[1].properties
	assert.eq(properties["bench.derive"], 5)
	assert.eq(properties["perf--canvas.pan.layoutMs"], nil)
end)

test.case("getPerfEvents sends nothing for an empty report", function(assert)
	assert.eq(#getPerfEvents(raw("{}"), CONTEXT), 0)
end)
