local types = require("@root/types")

type Item = types.Item

--[[
	Moves an image's `data.workspace`, the canvas its asset lives in, to
	`data.canvas`, the name it has had since workspaces became canvases. A value
	already under `canvas` wins.
]]
local function migrateImageCanvas(item: Item)
	local workspace = item.data.workspace

	if type(workspace) == "string" and item.data.canvas == nil then
		item.data.canvas = workspace
	end

	item.data.workspace = nil
end

return migrateImageCanvas
