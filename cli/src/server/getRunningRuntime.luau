local fs = require("@std/fs")
local net = require("@std/net")
local path = require("@std/path")

local fileNames = require("@root/fileNames")
local isProcessAlive = require("@root/server/isProcessAlive")
local readRuntime = require("@root/server/readRuntime")
local removeRuntime = require("@root/server/removeRuntime")

type Runtime = readRuntime.Runtime

local function getRunningRuntime(
	root: string,
	checkProcess: ((number) -> boolean)?,
	checkEndpoint: ((string) -> boolean)?
): Runtime?
	local file = path.join(root, fileNames.runtime)
	local runtime = readRuntime(root)
	if not runtime then
		if fs.exists(file) then
			removeRuntime(root)
		end
		return nil
	end

	local isAlive = checkProcess or isProcessAlive
	local responds = checkEndpoint
		or function(url: string): boolean
			local succeeded, response = pcall(function()
				return net.request(`{url}/api/workspaces`)
			end)
			return succeeded and response.status == 200
		end
	if not isAlive(runtime.pid) or not responds(runtime.url) then
		removeRuntime(root, runtime)
		return nil
	end

	return runtime
end

return getRunningRuntime
