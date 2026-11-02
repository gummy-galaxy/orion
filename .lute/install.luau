--[[
	Installs what working on Orion needs.

	lute run install
		Installs the CLI's Luau packages and copies each one from ~/.loom/store
		into workspace/orion-cli/packages, where `@pkg` points. `lute compile`
		bundles a package only when it shares a folder with the CLI's source
		above the home directory, so a checkout outside home, or on another
		drive like a Windows runner's, builds a binary that fails on its first
		require. A copy beside the source bundles from anywhere, once each
		copy's own aliases into ~/.loom/store point at its sibling copies.

	lute run install sqlite
		Installs a pinned `sqlite3` command on a Linux or Windows x86_64 CI
		runner that has none, which the CLI's index specs need. Downloads
		SQLite's own tools archive, checks its SHA-256, unpacks `sqlite3` into
		the runner's temporary folder, and adds that folder to the job's path.
		Does nothing when `sqlite3` already runs.
]]
local crypto = require("@lute/crypto")
local fs = require("@std/fs")
local net = require("@std/net")
local path = require("@std/path")
local process = require("@std/process")
local project = require("@repository/project")
local system = require("@std/system")

local run = require("@workspace/orion-cli/src/common/process/run")
local runScript = require("@workspace/orion-cli/src/common/process/runScript")

local isWindows = system.win32

local STORE_PATH = path.join(process.homedir(), ".loom", "store")
local PACKAGES_PATH = path.join(project.CLI_PATH, "packages")
local CONFIG_FILES = { [".luaurc"] = true, [".config.luau"] = true }

-- Each platform's SQLite tools archive, with the SHA-256 it was published with.
local SQLITE_ARCHIVE = if isWindows
	then {
		url = "https://www.sqlite.org/2025/sqlite-tools-win-x64-3500400.zip",
		sha256 = "8ce18347ea86a1ce65f33b533d2f144d8d1237140529fbf818574ca11fa13ad5",
		program = "sqlite3.exe",
	}
	else {
		url = "https://www.sqlite.org/2025/sqlite-tools-linux-x64-3500400.zip",
		sha256 = "2c61fe3f6bfcf4ab0cad6c4edf1fa1cae93bbb816b744bef52a4bdde5bf7bf38",
		program = "sqlite3",
	}

-- Copies a package in Lute rather than with `cp`, which Windows lacks. A
-- config file's aliases into the store are rewritten to the packages folder,
-- relative to that file, so they resolve inside the bundle.
local function copyPackage(source: path.Path, destination: path.Path, depth: number)
	fs.createDirectory(destination, { makeParents = true })

	for _, entry in fs.listDirectory(source) do
		local from, to = path.join(source, entry.name), path.join(destination, entry.name)

		if entry.type == "dir" then
			copyPackage(from, to, depth + 1)
		elseif entry.type == "file" and CONFIG_FILES[entry.name] then
			local packagesFromHere = string.rep("../", depth) .. ".."
			local config = fs.readFileToString(from):gsub("~/%.loom/store", packagesFromHere)
			fs.writeStringToFile(to, config)
		elseif entry.type == "file" then
			fs.copy(from, to)
		end
	end
end

local function installPackages()
	run("lute", { "pkg", "install" }, { cwd = project.CLI_PATH })

	local lock = require("@workspace/orion-cli/loom.lock") :: any

	if fs.exists(PACKAGES_PATH) then
		fs.removeDirectory(PACKAGES_PATH, { recursive = true })
	end

	for packageId in lock.packages :: { [string]: unknown } do
		copyPackage(path.join(STORE_PATH, packageId), path.join(PACKAGES_PATH, packageId), 0)
	end
end

local function toHex(digest: buffer): string
	local parts: { string } = {}

	for index = 0, buffer.len(digest) - 1 do
		table.insert(parts, string.format("%02x", buffer.readu8(digest, index)))
	end

	return table.concat(parts)
end

local function canRunSqlite(): boolean
	local succeeded, result = pcall(function()
		return process.run({ "sqlite3", "-version" })
	end)

	return succeeded and result.ok
end

local function installSqlite()
	if canRunSqlite() then
		print("sqlite3 is already installed")
		return
	end

	local folder = tostring(path.join(assert(process.env.RUNNER_TEMP, "RUNNER_TEMP isn't set"), "sqlite"))
	local archive = tostring(path.join(folder, "sqlite-tools.zip"))
	local response = net.request(SQLITE_ARCHIVE.url)
	assert(response.ok, `downloading {SQLITE_ARCHIVE.url} failed with status {response.status}`)

	local digest = toHex(crypto.digest(crypto.hash.sha256, response.body))
	assert(
		digest == SQLITE_ARCHIVE.sha256,
		`{SQLITE_ARCHIVE.url} has SHA-256 {digest}, expected {SQLITE_ARCHIVE.sha256}`
	)

	fs.createDirectory(folder, { makeParents = true })
	fs.writeStringToFile(archive, response.body)

	-- Windows runners have no unzip, but their bsdtar reads zip archives.
	local unpacked = if isWindows
		then process.run({ "tar", "-xf", archive, "-C", folder, SQLITE_ARCHIVE.program }, { stdio = "inherit" })
		else process.run(
			{ "unzip", "-o", "-j", archive, SQLITE_ARCHIVE.program, "-d", folder },
			{ stdio = "inherit" }
		)
	assert(unpacked.ok, `unpacking {archive} failed`)

	if not isWindows then
		assert(process.run({ "chmod", "+x", tostring(path.join(folder, SQLITE_ARCHIVE.program)) }).ok, "chmod failed")
	end

	local githubPath = assert(process.env.GITHUB_PATH, "GITHUB_PATH isn't set")
	local existing = if fs.exists(githubPath) then fs.readFileToString(githubPath) else ""
	fs.writeStringToFile(githubPath, `{existing}{folder}\n`)
	print(`installed sqlite3 into {folder}`)
end

local INSTALLERS: { [string]: () -> () } = {
	sqlite = installSqlite,
}

runScript(function()
	local target = process.args[2]

	if target == nil then
		installPackages()
		return
	end

	local install = INSTALLERS[target]
	assert(install, `unknown install target {target}; try lute run install, or lute run install sqlite`)
	install()
end)
