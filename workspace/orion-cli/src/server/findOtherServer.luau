local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@std/net")
local path = require("@std/path")
local process = require("@std/process")

local fileNames = require("@root/fileNames")
local getVersion = require("@root/getVersion")
local isProcessAlive = require("@root/server/isProcessAlive")

export type Server = {
	pid: number,
	-- Missing for a server from before `serve.json` recorded its build.
	version: string?,
}

export type Checks = {
	isAlive: ((number) -> boolean)?,
	responds: ((string) -> boolean)?,
}

-- A server answers on its canvas list, or on the workspace list before canvases
-- were renamed.
local function respondsToOrion(url: string): boolean
	for _, route in { "/api/canvases", "/api/workspaces" } do
		local succeeded, response = pcall(function()
			return net.request(`{url}{route}`)
		end)

		if succeeded and response.status == 200 then
			return true
		end
	end

	return false
end

--[[
	Returns the `orion server start` serving the data folder when it comes from
	a different build than this one, or nil. A migration calls this before it
	moves anything: that server keeps reading and writing the layout it knows,
	and its next write can replace what the migration produced. It reads
	`serve.json` loosely, since older servers wrote other fields, and checks
	that the process is alive and answers, so a stale record doesn't count.
]]
local function findOtherServer(root: string, checks: Checks?): Server?
	local file = path.join(root, fileNames.runtime)

	if not fs.exists(file) then
		return nil
	end

	local succeeded, record = pcall(function()
		return json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
	end)
	local pid = if succeeded and record then record.pid else nil
	local url = if succeeded and record then record.url else nil
	local version = if succeeded and record and type(record.version) == "string" then record.version else nil

	if type(pid) ~= "number" or type(url) ~= "string" or pid == process.pid() or version == getVersion() then
		return nil
	end

	local isAlive = if checks and checks.isAlive then checks.isAlive else isProcessAlive
	local responds = if checks and checks.responds then checks.responds else respondsToOrion

	if not isAlive(pid) or not responds(url) then
		return nil
	end

	return { pid = pid, version = version :: string? }
end

return findOtherServer
