local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local getClients = require("@root/cli/mcp/clients/getClients")
local getExecutableName = require("@root/platform/getExecutableName")
local mcpTypes = require("@root/cli/mcp/types")
local platformTypes = require("@root/platform/types")
local registerClients = require("@root/cli/mcp/clients/registerClients")
local testing = require("@root/testing")
local types = require("@root/types")
local unregisterClients = require("@root/cli/mcp/clients/unregisterClients")

type CommandResult = types.CommandResult
type Platform = platformTypes.Platform

local function succeeded(_argv: { string }, _stdin: string?): CommandResult
	return { ok = true, exitCode = 0, stdout = "", stderr = "" }
end

local function quiet(_line: string) end

local function command(root: path.Pathlike, name: string): path.Path
	local file = path.join(root, "tools", name)
	fs.createDirectory(path.dirname(file), { makeParents = true })
	fs.writeStringToFile(file, "")
	return file
end

local function fixture(name: string, platform: Platform?)
	local root = testing.directory(name)
	local binary = path.join(root, "cli", "build", getExecutableName(platform or "macos", "orion"))
	fs.createDirectory(path.dirname(binary), { makeParents = true })
	fs.writeStringToFile(binary, "binary\n")
	local home = path.join(root, "home")
	fs.createDirectory(path.join(home, ".cursor"), { makeParents = true })
	fs.writeStringToFile(
		path.join(home, ".cursor", "mcp.json"),
		json.serialize(
			json.object({
				mcpServers = json.object({ other = json.object({ command = "other" }) }),
			}),
			true
		)
	)
	return {
		root = root,
		binary = binary,
		home = home,
		path = tostring(path.join(root, "tools")),
	}
end

local function cursorServers(home: path.Path): json.Object?
	local config =
		json.asObject(json.deserialize(fs.readFileToString(path.join(home, ".cursor", "mcp.json"))) :: json.Value)
	return if config then json.asObject(config.mcpServers) else nil
end

local function recorder(calls: { string }): types.CommandRunner
	return function(argv: { string }, stdin: string?): CommandResult
		table.insert(calls, table.concat(argv, " "))
		return succeeded(argv, stdin)
	end
end

test.case("register points Cursor at orion mcp serve without dropping other servers", function(assert)
	local setup = fixture("mcp-register")
	local output: { string } = {}

	registerClients({
		binary = setup.binary,
		home = setup.home,
		clients = getClients(nil),
		write = function(line: string)
			table.insert(output, line)
		end,
		environment = { PATH = setup.path },
		platform = "macos",
		runner = function(_argv: { string }, _stdin: string?): CommandResult
			error("no CLI client should be spawned")
		end,
	})

	local text = table.concat(output, "\n")
	assert.strContains(text, "Skipped codex")
	assert.strContains(text, "Skipped claude")
	assert.strContains(text, "Registered orion in")

	local servers = cursorServers(setup.home)
	local other = if servers then json.asObject(servers.other) else nil
	local orion = if servers then json.asObject(servers.orion) else nil
	local arguments = if orion then json.asArray(orion.args) else nil
	assert.eq(other and other.command, "other")
	assert.eq(orion and orion.command, tostring(setup.binary))
	assert.eq(arguments and table.concat(arguments :: { any }, " "), "mcp serve")
	assert.eq(orion and orion.env, nil)
end)

test.case("register calls Codex and Claude and forwards ORION_DATA_DIR", function(assert)
	local setup = fixture("mcp-register-clients")
	command(setup.root, "codex")
	command(setup.root, "claude")
	local calls: { string } = {}
	local dataDir = tostring(path.join(setup.root, "data"))

	registerClients({
		binary = setup.binary,
		home = setup.home,
		clients = getClients("all"),
		write = quiet,
		environment = { PATH = setup.path, ORION_DATA_DIR = dataDir },
		platform = "macos",
		runner = recorder(calls),
	})

	local text = table.concat(calls, "\n")
	assert.strContains(text, `mcp add orion --env ORION_DATA_DIR={dataDir} -- {setup.binary} mcp serve`)
	assert.strContains(text, `mcp add orion -s user -e ORION_DATA_DIR={dataDir} -- {setup.binary} mcp serve`)
	assert.strContains(text, "mcp remove orion -s user")

	local servers = cursorServers(setup.home)
	local orion = if servers then json.asObject(servers.orion) else nil
	local environment = if orion then json.asObject(orion.env) else nil
	assert.eq(environment and environment.ORION_DATA_DIR, dataDir)
end)

test.case("register runs Windows npm shims through cmd.exe and serves from orion.exe", function(assert)
	local setup = fixture("mcp-register-windows", "windows")
	command(setup.root, "codex.cmd")
	command(setup.root, "claude.exe")
	local calls: { string } = {}

	registerClients({
		binary = setup.binary,
		home = setup.home,
		clients = getClients("all"),
		write = quiet,
		environment = { Path = `{setup.path};C:\\Windows`, PATHEXT = ".COM;.EXE;.BAT;.CMD", ComSpec = "C:\\cmd.exe" },
		platform = "windows",
		runner = recorder(calls),
	})

	local text = table.concat(calls, "\n")
	assert.strContains(text, `C:\\cmd.exe /d /c codex mcp add orion -- {setup.binary} mcp serve`)
	assert.strContains(text, `{command(setup.root, "claude.exe")} mcp add orion -s user -- {setup.binary} mcp serve`)
	assert.eq(path.basename(setup.binary), "orion.exe")
end)

test.case("unregister removes the clients it registered", function(assert)
	local setup = fixture("mcp-unregister")
	command(setup.root, "codex")
	local calls: { string } = {}
	local request: mcpTypes.ClientRequest = {
		binary = setup.binary,
		home = setup.home,
		clients = getClients("all"),
		write = quiet,
		environment = { PATH = setup.path },
		platform = "macos",
		runner = recorder(calls),
	}
	registerClients(request)
	unregisterClients(request)

	local servers = cursorServers(setup.home)
	local other = if servers then json.asObject(servers.other) else nil
	assert.eq(servers and servers.orion, nil)
	assert.eq(other and other.command, "other")
	assert.strContains(table.concat(calls, "\n"), "mcp remove orion")
end)

test.case("register asks to run from the built orion binary", function(assert)
	local setup = fixture("mcp-register-lute")
	local lute = command(setup.root, "lute")

	assert.throwsWith("Run register from the built orion binary, such as cli/build/orion", function()
		registerClients({
			binary = lute,
			home = setup.home,
			clients = { "cursor" },
			write = quiet,
			environment = { PATH = setup.path },
			platform = "macos",
			runner = succeeded,
		})
	end)
end)
