local fs = require("@std/fs")

-- The transcript file for a session id, in whichever project folder holds it.
local function findTranscript(dir: string, sessionId: string): string?
	local projects = `{dir}/projects`

	if not sessionId:match("^[%w%-]+$") or not fs.exists(projects) then
		return nil
	end

	for _, project in fs.listDirectory(projects) do
		local filePath = `{projects}/{project.name}/{sessionId}.jsonl`

		if project.type == "dir" and fs.exists(filePath) then
			return filePath
		end
	end

	return nil
end

return findTranscript
