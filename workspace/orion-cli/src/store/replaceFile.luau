local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local writeSequence = 0

-- Replaces one file of a canvas folder, given by its path under the folder such as `nodes/a.json`, in a single
-- move, so a reader sees either the old text or the new.
local function replaceFile(dir: string, file: string, contents: string)
	local full = tostring(path.join(dir, table.unpack(file:split("/"))))
	writeSequence += 1
	local temporary = `{full}.tmp.{process.pid()}.{writeSequence}`
	fs.writeStringToFile(temporary, contents)

	local succeeded, failureMessage = pcall(fs.move, temporary, full)

	if not succeeded then
		pcall(fs.remove, temporary)
		error(failureMessage, 0)
	end
end

return replaceFile
