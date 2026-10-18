local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")

local clearFocus = require("@root/store/clearFocus")
local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")

local writeSequence = 0

-- Records what an app window has open and selected. A closing window clears the focus only if it was the last
-- one to report, so closing a second window leaves the first one's focus in place.
local function putFocus(dir: string, tab: string, open: string?, selected: json.Array?, isClosed: boolean?)
	local file = tostring(path.join(dir, fileNames.focus))

	if isClosed then
		if fs.exists(file) then
			local didRead, value = pcall(function()
				return json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
			end)

			if didRead and value and value.tab == tab then
				clearFocus(dir)
			end
		end

		return
	end

	ensureDirectory(dir)
	writeSequence += 1
	local temporary = `{file}.tmp.{process.pid()}.{writeSequence}`
	local value = json.object({
		tab = tab,
		open = open or json.null,
		selected = selected or {},
		updatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	})
	local didWrite, message = pcall(function()
		fs.writeStringToFile(temporary, json.serialize(value, true))
		fs.move(temporary, file)
	end)

	if not didWrite then
		pcall(fs.remove, temporary)
		error(message, 0)
	end
end

return putFocus
