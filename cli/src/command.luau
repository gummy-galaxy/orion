local filesystem = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local types = require("@root/types")

local sequence = 0

local function run(argv: { string }, stdin: string?): types.CommandResult
	local command = argv
	local inputPath: string? = nil

	if stdin then
		sequence += 1
		inputPath = tostring(path.join(system.tmpdir(), `orion-agent-{process.pid()}-{sequence}.txt`))
		filesystem.writeStringToFile(inputPath, stdin)
		command = { "sh", "-c", 'input="$1"; shift; exec "$@" < "$input"', "sh", inputPath, table.unpack(argv) }
	end

	local succeeded, result = pcall(process.run, command, nil)

	if inputPath then
		filesystem.remove(inputPath)
	end

	if not succeeded then
		error(result, 0)
	end

	return {
		ok = result.ok,
		exitCode = result.exitcode,
		stdout = result.stdout,
		stderr = result.stderr,
	}
end

return run
