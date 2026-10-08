local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local fileNames = require("@root/fileNames")

export type Runtime = {
	pid: number,
	url: string,
	workspace: string,
	dataFolder: string,
	startedAt: string,
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
	local workspace = object.workspace
	local dataFolder = object.dataFolder
	local startedAt = object.startedAt
	if type(pid) ~= "number" or pid < 1 or pid % 1 ~= 0 then
		return nil
	end
	if
		type(url) ~= "string"
		or type(workspace) ~= "string"
		or type(dataFolder) ~= "string"
		or type(startedAt) ~= "string"
	then
		return nil
	end

	return { pid = pid, url = url, workspace = workspace, dataFolder = dataFolder, startedAt = startedAt }
end

return readRuntime
