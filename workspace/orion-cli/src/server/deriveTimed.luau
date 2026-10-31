local time = require("@std/time")

local derive = require("@root/graph/derive")
local graphTypes = require("@root/graph/types")
local performanceSummaries = require("@root/server/performanceSummaries")
local types = require("@root/types")

type Derived = graphTypes.Derived
type Timings = performanceSummaries.Timings

-- Derives a canvas the way the server sends it to the app, recording how long
-- it took and how big the canvas is for usage telemetry.
local function deriveTimed(doc: types.Doc, timings: Timings?): Derived
	local startedAt = time.now()
	local derived = derive(doc)

	if timings then
		local groupCount = 0

		for _ in derived.groups do
			groupCount += 1
		end

		timings.record("derive", time.since(startedAt) * 1000)
		timings.setCanvasSize(derived.canvas.total, groupCount)
	end

	return derived
end

return deriveTimed
