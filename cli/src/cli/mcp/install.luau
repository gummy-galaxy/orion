local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local platformDirs = require("@root/platformDirs")
local types = require("@root/types")

type CommandRunner = types.CommandRunner
type Platform = platformDirs.Platform

export type Request = {
	cliBin: string,
	home: string,
	clients: { string },
	write: (string) -> (),
	runner: CommandRunner,
	env: { [string]: string },
	platform: Platform,
}

local CLIENTS = { "codex", "claude", "cursor" }
local SERVE_ARGS = { "mcp", "serve" }

local function envValue(env: { [string]: string }, name: string): string?
	if env[name] then
		return env[name]
	end

	local wanted = string.upper(name)

	for key, value in env do
		if string.upper(key) == wanted then
			return value
		end
	end

	return nil
end

local function extensions(platform: Platform, env: { [string]: string }): { string }
	if platform ~= "windows" then
		return { "" }
	end

	local list: { string } = {}

	for extension in string.gmatch(envValue(env, "PATHEXT") or ".COM;.EXE;.BAT;.CMD", "[^;]+") do
		table.insert(list, string.lower(extension))
	end

	return list
end

local function findCommand(name: string, env: { [string]: string }, platform: Platform): string?
	local separator = if platform == "windows" then "[^;]+" else "[^:]+"

	for directory in string.gmatch(envValue(env, "PATH") or "", separator) do
		for _, extension in extensions(platform, env) do
			local candidate = path.join(directory, name .. extension)

			if fs.exists(candidate) then
				local kind = fs.type(candidate)

				if kind == "file" or kind == "link" then
					return tostring(candidate)
				end
			end
		end
	end

	return nil
end

local function isShellScript(program: string): boolean
	local extension = string.lower(path.extname(program))
	return extension == ".cmd" or extension == ".bat"
end

local function command(
	program: string,
	name: string,
	args: { string },
	env: { [string]: string },
	platform: Platform
): { string }
	local argv: { string }

	-- npm installs Codex and Claude as .cmd shims on Windows, which only cmd.exe can run.
	-- The bare name keeps a quoted path from leading the line, which cmd /c would unquote.
	if platform == "windows" and isShellScript(program) then
		argv = { envValue(env, "ComSpec") or "cmd.exe", "/d", "/c", name }
	else
		argv = { program }
	end

	for _, arg in args do
		table.insert(argv, arg)
	end

	return argv
end

local function clients(name: string?): { string }
	if name == nil or name == "all" then
		return table.clone(CLIENTS)
	end

	assert(table.find(CLIENTS, name) ~= nil, "client must be codex, claude, cursor, or all")
	return { name }
end

local function checkBinary(request: Request)
	local cliBin = request.cliBin
	assert(
		path.basename(cliBin) == platformDirs.executableName(request.platform, "orion")
			and fs.exists(cliBin)
			and fs.type(cliBin) == "file",
		"Run register from the built orion binary, such as cli/build/orion"
	)
end

local function dataDir(request: Request): string?
	local configured = request.env.ORION_DATA_DIR
	return if configured and configured ~= "" then tostring(path.resolve(configured)) else nil
end

local function cursorFile(home: string): string
	return tostring(path.join(home, ".cursor", "mcp.json"))
end

local function cursorAvailable(request: Request): boolean
	return fs.exists(path.join(request.home, ".cursor")) or findCommand("cursor", request.env, request.platform) ~= nil
end

local function readCursorConfig(file: string): json.Object
	if not fs.exists(file) then
		return json.object({ mcpServers = json.object({}) })
	end

	local parsed = json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
	assert(parsed, `invalid Cursor MCP config at {file}`)

	if not json.asObject(parsed.mcpServers) then
		parsed.mcpServers = json.object({})
	end

	return parsed
end

local function writeCursor(request: Request)
	local directory = tostring(path.join(request.home, ".cursor"))

	if not fs.exists(directory) then
		fs.createDirectory(directory, { makeParents = true })
	end

	local file = cursorFile(request.home)
	local config = readCursorConfig(file)
	local servers = assert(json.asObject(config.mcpServers))
	local entry = json.object({ command = request.cliBin, args = table.clone(SERVE_ARGS) })
	local configured = dataDir(request)

	if configured then
		entry.env = json.object({ ORION_DATA_DIR = configured })
	end

	servers.orion = entry
	config.mcpServers = servers
	fs.writeStringToFile(file, json.serialize(config, true))
end

local function clearCursor(home: string): boolean
	local file = cursorFile(home)

	if not fs.exists(file) then
		return false
	end

	local config = readCursorConfig(file)
	local servers = assert(json.asObject(config.mcpServers))

	if servers.orion == nil then
		return false
	end

	servers.orion = nil
	config.mcpServers = servers
	fs.writeStringToFile(file, json.serialize(config, true))
	return true
end

local function runClient(runner: CommandRunner, argv: { string }, required: boolean)
	local result = runner(argv, nil)

	if required then
		assert(result.ok, `{argv[1]} failed ({result.exitCode})`)
	end
end

local function removeArgs(client: string): { string }
	local argv = { "mcp", "remove", "orion" }

	if client == "claude" then
		table.insert(argv, "-s")
		table.insert(argv, "user")
	end

	return argv
end

local function addArgs(client: string, request: Request): { string }
	local argv = { "mcp", "add", "orion" }

	if client == "claude" then
		table.insert(argv, "-s")
		table.insert(argv, "user")
	end

	local configured = dataDir(request)

	if configured then
		table.insert(argv, if client == "claude" then "-e" else "--env")
		table.insert(argv, `ORION_DATA_DIR={configured}`)
	end

	table.insert(argv, "--")
	table.insert(argv, request.cliBin)

	for _, arg in SERVE_ARGS do
		table.insert(argv, arg)
	end

	return argv
end

local function register(request: Request)
	checkBinary(request)

	local runner = request.runner
	local registered = 0

	for _, client in request.clients do
		if client == "cursor" then
			if cursorAvailable(request) or #request.clients == 1 then
				writeCursor(request)
				request.write(
					`Registered orion in {cursorFile(request.home)}. Restart Cursor or toggle the server in Settings.`
				)
				registered += 1
			else
				request.write("Skipped Cursor: ~/.cursor was not found.")
			end
		else
			local program = findCommand(client, request.env, request.platform)

			if program == nil then
				assert(#request.clients ~= 1, `{client} is not on PATH`)
				request.write(`Skipped {client}: {client} is not on PATH.`)
			else
				runClient(runner, command(program, client, removeArgs(client), request.env, request.platform), false)
				runClient(
					runner,
					command(program, client, addArgs(client, request), request.env, request.platform),
					true
				)
				request.write(`Registered orion with {client}.`)
				registered += 1
			end
		end
	end

	if #request.clients > 0 then
		assert(registered > 0, "No MCP clients were registered.")
	end

	request.write(`Clients will run {request.cliBin} mcp serve.`)
end

local function unregister(request: Request)
	local runner = request.runner

	for _, client in request.clients do
		if client == "cursor" then
			if clearCursor(request.home) then
				request.write(`Removed orion from {cursorFile(request.home)}.`)
			else
				request.write("Cursor had no orion server.")
			end
		else
			local program = findCommand(client, request.env, request.platform)

			if program == nil then
				assert(#request.clients ~= 1, `{client} is not on PATH`)
				request.write(`Skipped {client}: {client} is not on PATH.`)
			else
				runClient(runner, command(program, client, removeArgs(client), request.env, request.platform), false)
				request.write(`Removed orion from {client}.`)
			end
		end
	end
end

return table.freeze({
	clients = clients,
	register = register,
	unregister = unregister,
})
