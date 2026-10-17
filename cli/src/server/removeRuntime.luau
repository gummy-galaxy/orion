local fs = require("@std/fs")
local path = require("@std/path")

local fileNames = require("@root/fileNames")
local readRuntime = require("@root/server/readRuntime")

type Runtime = readRuntime.Runtime

local function removeRuntime(root: string, expected: Runtime?)
	local file = path.join(root, fileNames.runtime)
	if not fs.exists(file) then
		return
	end

	if expected then
		local current = readRuntime(root)
		if
			not current
			or current.pid ~= expected.pid
			or current.url ~= expected.url
			or current.canvas ~= expected.canvas
			or current.dataFolder ~= expected.dataFolder
			or current.startedAt ~= expected.startedAt
		then
			return
		end
	end

	fs.remove(file)
end

return removeRuntime
