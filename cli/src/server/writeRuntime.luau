local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")

local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local readRuntime = require("@root/server/readRuntime")

type Runtime = readRuntime.Runtime

local sequence = 0

local function writeRuntime(root: string, runtime: Runtime)
	ensureDirectory(root)

	local file = path.join(root, fileNames.runtime)
	sequence += 1
	local temporary = `{file}.tmp.{process.pid()}.{sequence}`
	local succeeded, failure = pcall(function()
		fs.writeStringToFile(
			temporary,
			json.serialize(
				json.object({
					pid = runtime.pid,
					url = runtime.url,
					canvas = runtime.canvas,
					dataFolder = runtime.dataFolder,
					startedAt = runtime.startedAt,
					version = runtime.version,
				}),
				true
			)
		)
		fs.move(temporary, file)
	end)
	if not succeeded then
		pcall(fs.remove, temporary)
		error(failure, 0)
	end
end

return writeRuntime
