local json = require("@std/json")

local sessionTypes = require("@root/sessions/types")

type StartOptions = sessionTypes.StartOptions

-- Start options as JSON, for orion session presets and the app.
local function describeStartOptions(options: StartOptions): json.Object
	local presets: json.Array = {}

	for _, preset in options.presets do
		table.insert(presets, json.object({ id = preset.id, label = preset.label }))
	end

	return json.object({
		presets = presets,
		agent = options.agent or json.null,
		folder = options.folder or json.null,
		problem = options.problem or json.null,
	})
end

return describeStartOptions
