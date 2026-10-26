--[[
	Installs a pinned `sqlite3` command on a Linux x86_64 CI runner that has
	none, which the CLI's index specs need. Downloads SQLite's own tools
	archive, checks its SHA-256, unpacks `sqlite3` into the runner's temporary
	folder, and adds that folder to the job's path. Does nothing when `sqlite3`
	already runs.

	lute run install-sqlite
]]
local crypto = require("@lute/crypto")
local fs = require("@std/fs")
local net = require("@std/net")
local path = require("@std/path")
local process = require("@std/process")

local runScript = require("@cli/runScript")

local URL = "https://www.sqlite.org/2025/sqlite-tools-linux-x64-3500400.zip"
local SHA256 = "2c61fe3f6bfcf4ab0cad6c4edf1fa1cae93bbb816b744bef52a4bdde5bf7bf38"

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

runScript(function()
	if canRunSqlite() then
		print("sqlite3 is already installed")
		return
	end

	local folder = tostring(path.join(assert(process.env.RUNNER_TEMP, "RUNNER_TEMP isn't set"), "sqlite"))
	local archive = tostring(path.join(folder, "sqlite-tools.zip"))
	local response = net.request(URL)
	assert(response.ok, `downloading {URL} failed with status {response.status}`)

	local digest = toHex(crypto.digest(crypto.hash.sha256, response.body))
	assert(digest == SHA256, `{URL} has SHA-256 {digest}, expected {SHA256}`)

	fs.createDirectory(folder, { makeParents = true })
	fs.writeStringToFile(archive, response.body)

	local unpacked = process.run({ "unzip", "-o", "-j", archive, "sqlite3", "-d", folder }, { stdio = "inherit" })
	assert(unpacked.ok, "unzip failed")
	assert(process.run({ "chmod", "+x", tostring(path.join(folder, "sqlite3")) }).ok, "chmod failed")

	local githubPath = assert(process.env.GITHUB_PATH, "GITHUB_PATH isn't set")
	local existing = if fs.exists(githubPath) then fs.readFileToString(githubPath) else ""
	fs.writeStringToFile(githubPath, `{existing}{folder}\n`)
	print(`installed sqlite3 into {folder}`)
end)
