local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local install = require("@root/cli/mcp/install")
local platformDirs = require("@root/platformDirs")
local testing = require("@root/testing")
local types = require("@root/types")

type CommandResult = types.CommandResult
type Platform = platformDirs.Platform

local function succeeded(_argv: { string }, _stdin: string?): CommandResult
	return { ok = true, exitCode = 0, stdout = "", stderr = "" }
end

local function quiet(_line: string) end

local function command(root: string, name: string): string
	local file = path.join(root, "tools", name)
	fs.createDirectory(path.dirname(file), { makeParents = true })
	fs.writeStringToFile(file, "")
	return tostring(file)
end

local function fixture(name: string, platform: Platform?)
	local selected: Platform = platform or "macos"
	local root = testing.directory(name)
	local source = path.join(root, "mcp")
	fs.createDirectory(path.join(source, "node_modules", "pkg"), { makeParents = true })
	fs.writeStringToFile(path.join(source, "server.mjs"), "export {}\n")
	fs.writeStringToFile(path.join(source, "node_modules", "pkg", "index.js"), "module.exports = {}\n")
	fs.symbolicLink("node_modules/pkg/index.js", path.join(source, "link.txt"))
	local bin = path.join(root, "cli", "build", platformDirs.executableName(selected, "orion"))
	fs.createDirectory(path.dirname(bin), { makeParents = true })
	fs.writeStringToFile(bin, "binary\n")
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
	command(root, if selected == "windows" then "node.exe" else "node")
	return {
		root = root,
		source = tostring(source),
		bin = tostring(bin),
		home = tostring(home),
		path = tostring(path.join(root, "tools")),
	}
end

test.case("register installs the server and records Cursor without dropping other servers", function(assert)
	local setup = fixture("mcp-register")
	local output: { string } = {}

	install.register({
		source = setup.source,
		cliBin = setup.bin,
		installDir = tostring(path.join(setup.root, "installed")),
		home = setup.home,
		clients = install.clients(nil),
		write = function(line: string)
			table.insert(output, line)
		end,
		env = { PATH = setup.path },
		platform = "macos",
		runner = function(_argv: { string }, _stdin: string?): CommandResult
			error("no CLI client should be spawned")
		end,
	})

	local text = table.concat(output, "\n")
	assert.eq(fs.readFileToString(path.join(setup.root, "installed", "server.mjs")), "export {}\n")
	assert.eq(fs.readFileToString(path.join(setup.root, "installed", "orion")), "binary\n")
	assert.eq(fs.readFileToString(path.join(setup.root, "installed", "link.txt")), "module.exports = {}\n")
	assert.strContains(text, "Skipped codex")
	assert.strContains(text, "Skipped claude")
	assert.strContains(text, "Registered orion in")

	local config =
		json.asObject(json.deserialize(fs.readFileToString(path.join(setup.home, ".cursor", "mcp.json"))) :: json.Value)
	local servers = if config then json.asObject(config.mcpServers) else nil
	local other = if servers then json.asObject(servers.other) else nil
	local orion = if servers then json.asObject(servers.orion) else nil
	local args = if orion then json.asArray(orion.args) else nil
	assert.eq(other and other.command, "other")
	assert.eq(orion and orion.command, command(setup.root, "node"))
	assert.eq(args and args[1], tostring(path.join(setup.root, "installed", "server.mjs")))
end)

test.case("register calls Codex and Claude when they are installed", function(assert)
	local setup = fixture("mcp-register-clients")
	command(setup.root, "codex")
	command(setup.root, "claude")
	local calls: { string } = {}

	install.register({
		source = setup.source,
		cliBin = setup.bin,
		installDir = tostring(path.join(setup.root, "installed")),
		home = setup.home,
		clients = install.clients("all"),
		write = quiet,
		env = { PATH = setup.path },
		platform = "macos",
		runner = function(argv: { string }, stdin: string?): CommandResult
			table.insert(calls, table.concat(argv, " "))
			return succeeded(argv, stdin)
		end,
	})

	local text = table.concat(calls, "\n")
	assert.strContains(text, "mcp add orion --env ORION_BIN=")
	assert.strContains(text, "mcp add orion -s user -e ORION_BIN=")
	assert.strContains(text, "-s user")
end)

test.case("register runs Windows npm shims through cmd.exe and installs orion.exe", function(assert)
	local setup = fixture("mcp-register-windows", "windows")
	command(setup.root, "codex.cmd")
	command(setup.root, "claude.exe")
	local calls: { string } = {}

	install.register({
		source = setup.source,
		cliBin = setup.bin,
		installDir = tostring(path.join(setup.root, "installed")),
		home = setup.home,
		clients = install.clients("all"),
		write = quiet,
		env = { Path = `{setup.path};C:\\Windows`, PATHEXT = ".COM;.EXE;.BAT;.CMD", ComSpec = "C:\\cmd.exe" },
		platform = "windows",
		runner = function(argv: { string }, stdin: string?): CommandResult
			table.insert(calls, table.concat(argv, " "))
			return succeeded(argv, stdin)
		end,
	})

	local text = table.concat(calls, "\n")
	assert.eq(fs.readFileToString(path.join(setup.root, "installed", "orion.exe")), "binary\n")
	assert.strContains(text, "C:\\cmd.exe /d /c codex mcp add orion --env ORION_BIN=")
	assert.strContains(text, `{command(setup.root, "claude.exe")} mcp add orion -s user -e ORION_BIN=`)
	assert.strContains(text, `{command(setup.root, "node.exe")} `)
	assert.strContains(text, "orion.exe")
end)

test.case("unregister removes the clients it registered", function(assert)
	local setup = fixture("mcp-unregister")
	command(setup.root, "codex")
	local calls: { string } = {}
	local request: install.Request = {
		source = setup.source,
		cliBin = setup.bin,
		installDir = tostring(path.join(setup.root, "installed")),
		home = setup.home,
		clients = install.clients("all"),
		write = quiet,
		env = { PATH = setup.path },
		platform = "macos",
		runner = function(argv: { string }, stdin: string?): CommandResult
			table.insert(calls, table.concat(argv, " "))
			return succeeded(argv, stdin)
		end,
	}
	install.register(request)
	install.unregister(request)

	local config =
		json.asObject(json.deserialize(fs.readFileToString(path.join(setup.home, ".cursor", "mcp.json"))) :: json.Value)
	local servers = if config then json.asObject(config.mcpServers) else nil
	local other = if servers then json.asObject(servers.other) else nil
	assert.eq(servers and servers.orion, nil)
	assert.eq(other and other.command, "other")
	assert.strContains(table.concat(calls, "\n"), "mcp remove orion")
end)

test.case("locate finds the checkout next to the built CLI", function(assert)
	local setup = fixture("mcp-locate")
	local located = install.locate(setup.bin, tostring(setup.root), setup.home, {}, "macos")
	assert.eq(located.source, setup.source)
	assert.eq(located.cliBin, setup.bin)
	assert.eq(located.installDir, tostring(path.join(setup.home, "Library", "Application Support", "Orion", "mcp")))

	local windows = fixture("mcp-locate-windows", "windows")
	local windowsLocated =
		install.locate(windows.bin, tostring(windows.root), windows.home, { APPDATA = "/Roaming" }, "windows")
	assert.eq(windowsLocated.cliBin, windows.bin)
	assert.eq(windowsLocated.installDir, tostring(path.join("/Roaming", "Orion", "mcp")))

	fs.removeDirectory(path.join(setup.source, "node_modules"), { recursive = true })
	assert.throwsWith("Install MCP dependencies first: npm ci --prefix mcp", function()
		install.locate(setup.bin, tostring(setup.root), setup.home, {}, "macos")
	end)
end)

test.case("register asks for the CLI and MCP dependencies first", function(assert)
	local root = testing.directory("mcp-install-missing")
	local source = tostring(path.join(root, "mcp"))
	fs.createDirectory(source, { makeParents = true })
	local home = tostring(path.join(root, "home"))

	assert.throwsWith("Build the Orion CLI first: (cd cli && lute run build)", function()
		install.register({
			source = source,
			cliBin = tostring(path.join(root, "missing")),
			installDir = tostring(path.join(root, "installed")),
			home = home,
			clients = {},
			write = quiet,
			env = { PATH = "" },
			platform = "macos",
			runner = succeeded,
		})
	end)
end)
