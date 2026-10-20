local json = require("@std/json")

-- Refuses a canvas object below data version 2. One with no version is from before versions were recorded. Version 1
-- kept a card's pull request, issue, and branch in their own fields instead of refs.
local function checkDataVersion(root: json.Object, file: string?)
	local version = if type(root.version) == "number" then root.version else 1
	assert(
		version >= 2,
		`{file or "This canvas"} was saved as data version 1, which Orion no longer reads. To upgrade it, make one `
			.. "change to it with an Orion built from commit 40320db6 or earlier, such as moving a card, then try again."
	)
end

return checkDataVersion
