local label = require("@lib/label")
local runGh = require("@lib/runGh")

-- Adds the priority label to a pull request, creating the label first when the repository lacks it.
local function addPriorityLabel(repository: string, pullRequest: string)
	runGh({
		"label",
		"create",
		label.NAME,
		"--repo",
		repository,
		"--color",
		label.COLOR,
		"--description",
		label.DESCRIPTION,
		"--force",
	})

	runGh({ "pr", "edit", pullRequest, "--repo", repository, "--add-label", label.NAME })
end

return addPriorityLabel
