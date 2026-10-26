local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")

local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local readSettings = require("@root/settings/readSettings")

local writeSequence = 0

-- Applies changed preferences over the saved ones. A null value removes that
-- preference.
return function(root: string, changes: json.Object): json.Object
	local settings = readSettings(root)

	for key, value in changes do
		-- Skips the marker json.object keeps on every object.
		if type(key) == "string" then
			settings[key] = if value == json.null then nil else value
		end
	end

	ensureDirectory(root)

	local file = tostring(path.join(root, fileNames.settings))
	writeSequence += 1
	local temporary = `{file}.tmp.{process.pid()}.{writeSequence}`
	local didWrite, message = pcall(function()
		fs.writeStringToFile(temporary, json.serialize(settings, true))
		fs.move(temporary, file)
	end)

	if not didWrite then
		pcall(fs.remove, temporary)
		error(message, 0)
	end

	return settings
end
