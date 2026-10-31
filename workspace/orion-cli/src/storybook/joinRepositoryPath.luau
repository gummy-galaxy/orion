local path = require("@std/path")

-- Joins and normalizes a path from the repository root with forward slashes on
-- every platform, so it matches the paths git and Storybook report.
local function joinRepositoryPath(base: path.Pathlike, relative: string): string
	return (tostring(path.normalize(path.join(base, relative))):gsub("\\", "/"))
end

return joinRepositoryPath
