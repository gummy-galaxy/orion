local label = require("@lib/label")
local runGh = require("@lib/runGh")

-- Removes the priority label from a pull request.
local function removePriorityLabel(repository: string, pullRequest: string)
	runGh({ "pr", "edit", pullRequest, "--repo", repository, "--remove-label", label.NAME })
end

return removePriorityLabel
