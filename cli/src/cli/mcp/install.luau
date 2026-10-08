local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")

local platformDirs = require("@root/platformDirs")
local types = require("@root/types")

type CommandRunner = types.CommandRunner
type Platform = platformDirs.Platform

export type Location = {
	source: string,
	cliBin: string,
	installDir: string,
	home: string,
}

export type Request = {
	source: string,
	cliBin: string,
	installDir: string,
	home: string,
	clients: { string },
	write: (string) -> (),
	runner: CommandRunner,
	env: { [string]: string },
	platform: Platform,
}

local CLIENTS = { "codex", "claude", "cursor" }

local function samePath(left: string, right: string): boolean
	return tostring(path.normalize(left)) == tostring(path.normalize(right))
end

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

local function copyTree(source: string, destination: string)
	if fs.type(source) == "dir" then
		if not fs.exists(destination) then
			fs.createDirectory(destination, { makeParents = true })
		end

		for _, entry in fs.listDirectory(source) do
			copyTree(tostring(path.join(source, entry.name)), tostring(path.join(destination, entry.name)))
		end

		return
	end

	local parent = path.dirname(destination)

	if not fs.exists(parent) then
		fs.createDirectory(parent, { makeParents = true })
	end

	if fs.exists(destination) then
		fs.remove(destination)
	end

	fs.copy(source, destination)
end

local function serverReady(directory: string): boolean
	return fs.exists(path.join(directory, "server.mjs")) and fs.exists(path.join(directory, "node_modules"))
end

local function clients(name: string?): { string }
	if name == nil or name == "all" then
		return table.clone(CLIENTS)
	end

	assert(table.find(CLIENTS, name) ~= nil, "client must be codex, claude, cursor, or all")
	return { name }
end

local function locate(
	execPath: string,
	cwd: string,
	home: string,
	env: { [string]: string },
	platform: Platform
): Location
	local environment = env
	local installDir = tostring(path.join(platformDirs.dataDir(platform, home, env), "mcp"))
	local binName = platformDirs.executableName(platform, "orion")
	local candidates = {
		tostring(path.join(path.dirname(execPath), "..", "..", "mcp")),
		tostring(path.join(path.dirname(execPath), "..", "mcp")),
		tostring(path.join(cwd, "mcp")),
		tostring(path.join(cwd, "..", "mcp")),
		installDir,
	}
	local source: string? = nil
	local sawServer = false

	for _, candidate in candidates do
		if fs.exists(path.join(candidate, "server.mjs")) then
			sawServer = true

			if fs.exists(path.join(candidate, "node_modules")) then
				source = candidate
				break
			end
		end
	end

	local found = assert(
		source,
		if sawServer
			then "Install MCP dependencies first: npm ci --prefix mcp"
			else "Could not find the MCP server. Run this from an Orion checkout."
	)

	local cliBin = environment.ORION_BIN

	if cliBin == nil or not fs.exists(cliBin) then
		local built = {
			tostring(path.join(cwd, "build", binName)),
			tostring(path.join(cwd, "cli", "build", binName)),
			tostring(path.join(path.dirname(found), "cli", "build", binName)),
			tostring(path.join(installDir, binName)),
		}
		cliBin = nil

		if path.basename(execPath) == binName then
			table.insert(built, 1, execPath)
		end

		for _, candidate in built do
			if fs.exists(candidate) then
				cliBin = candidate
				break
			end
		end
	end

	assert(cliBin ~= nil and fs.exists(cliBin), "Build the Orion CLI first: (cd cli && lute run build)")

	return {
		source = tostring(path.normalize(found)),
		cliBin = tostring(path.normalize(cliBin)),
		installDir = tostring(path.normalize(installDir)),
		home = home,
	}
end

local function installedBinary(request: Request): string
	return tostring(path.join(request.installDir, platformDirs.executableName(request.platform, "orion")))
end

local function prepare(request: Request)
	local source, cliBin, installDir = request.source, request.cliBin, request.installDir
	assert(fs.exists(cliBin) and fs.type(cliBin) == "file", "Build the Orion CLI first: (cd cli && lute run build)")
	assert(serverReady(source), "Install MCP dependencies first: npm ci --prefix mcp")

	if not samePath(source, installDir) then
		if fs.exists(installDir) then
			fs.removeDirectory(installDir, { recursive = true })
		end

		copyTree(source, installDir)
	end

	local installedBin = installedBinary(request)

	if not samePath(cliBin, installedBin) then
		fs.copy(cliBin, installedBin)
	end

	if request.platform ~= "windows" then
		local chmod = process.run({ "chmod", "+x", installedBin })
		assert(chmod.ok, `chmod failed: {chmod.stderr}`)
	end
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

local function writeCursor(home: string, node: string, server: string, bin: string)
	local directory = tostring(path.join(home, ".cursor"))

	if not fs.exists(directory) then
		fs.createDirectory(directory, { makeParents = true })
	end

	local file = cursorFile(home)
	local config = readCursorConfig(file)
	local servers = assert(json.asObject(config.mcpServers))
	servers.orion = json.object({
		command = node,
		args = { server },
		env = json.object({ ORION_BIN = bin }),
	})
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

local function addArgs(client: string, bin: string, node: string, server: string): { string }
	local argv = { "mcp", "add", "orion" }

	if client == "claude" then
		table.insert(argv, "-s")
		table.insert(argv, "user")
		table.insert(argv, "-e")
	else
		table.insert(argv, "--env")
	end

	table.insert(argv, `ORION_BIN={bin}`)
	table.insert(argv, "--")
	table.insert(argv, node)
	table.insert(argv, server)
	return argv
end

local function register(request: Request)
	prepare(request)

	local node = findCommand("node", request.env, request.platform)
	assert(node, "node is not on PATH")
	local server = tostring(path.join(request.installDir, "server.mjs"))
	local bin = installedBinary(request)
	local runner = request.runner
	local registered = 0

	for _, client in request.clients do
		if client == "cursor" then
			if cursorAvailable(request) or #request.clients == 1 then
				writeCursor(request.home, node, server, bin)
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
					command(program, client, addArgs(client, bin, node, server), request.env, request.platform),
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

	request.write(`Installed the MCP server at {request.installDir}.`)
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
	command = command,
	findCommand = findCommand,
	locate = locate,
	register = register,
	unregister = unregister,
})
