local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local fileNames = require("@root/fileNames")

export type Runtime = {
	pid: number,
	url: string,
	canvas: string,
	dataFolder: string,
	startedAt: string,
	-- The build serving the folder, from `getVersion`. Servers from before it
	-- was recorded leave it out.
	version: string?,
}

local function readRuntime(root: string): Runtime?
	local file = path.join(root, fileNames.runtime)
	if not fs.exists(file) then
		return nil
	end

	local succeeded, value = pcall(function()
		return json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
	end)
	local object = if succeeded then value else nil
	if not object then
		return nil
	end

	local pid = object.pid
	local url = object.url
	local canvas = object.canvas
	local dataFolder = object.dataFolder
	local startedAt = object.startedAt
	local version = object.version
	if type(pid) ~= "number" or pid < 1 or pid % 1 ~= 0 then
		return nil
	end
	if
		type(url) ~= "string"
		or type(canvas) ~= "string"
		or type(dataFolder) ~= "string"
		or type(startedAt) ~= "string"
		or (version ~= nil and type(version) ~= "string")
	then
		return nil
	end

	return {
		pid = pid,
		url = url,
		canvas = canvas,
		dataFolder = dataFolder,
		startedAt = startedAt,
		version = version :: string?,
	}
end

return readRuntime
