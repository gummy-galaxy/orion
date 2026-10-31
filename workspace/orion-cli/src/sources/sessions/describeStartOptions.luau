local json = require("@std/json")

local sessionTypes = require("@root/sources/sessions/types")

type StartOptions = sessionTypes.StartOptions

-- Start options as JSON, for orion session presets and the app.
local function describeStartOptions(options: StartOptions): json.Object
	local presets: json.Array = {}

	for _, preset in options.presets do
		table.insert(presets, json.object({ id = preset.id, label = preset.label }))
	end

	return json.object({
		presets = presets,
		agent = options.agent,
		attaches = options.attaches,
		repo = options.repo or json.null,
		branch = options.branch or json.null,
		place = options.place,
		folder = options.folder or json.null,
		problem = options.problem or json.null,
	})
end

return describeStartOptions
