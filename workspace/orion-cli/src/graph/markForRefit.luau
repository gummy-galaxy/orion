local types = require("@root/types")

type Item = types.Item

-- Asks the app to tidy a group whose members changed. A pending marker already
-- places it, so it is kept, and a custom group is left as the user arranged it.
local function markForRefit(group: Item)
	if group.data.layout == nil and group.data.arrange ~= "custom" then
		group.data.layout = "refit"
	end
end

return markForRefit
