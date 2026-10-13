local FlipbookBatteries = require("@flipbook-batteries")
local fs = require("@std/fs")
local process = require("@std/process")
local project = require("@repo/project")
local system = require("@std/system")

local run = FlipbookBatteries.run

local outputPath = tostring(project.BUILD_OUTPUT)
local windowsOutputPath = outputPath .. ".exe"

for _, stalePath in { outputPath, windowsOutputPath } do
	if fs.exists(stalePath) then
		fs.remove(stalePath)
	end
end

if system.os:lower() == "windows_nt" then
	outputPath = windowsOutputPath
end

if not fs.exists(project.BUILD_PATH) then
	fs.createDirectory(project.BUILD_PATH, { makeParents = true })
end

run("lute", {
	"compile",
	"cli.luau",
	"--output",
	outputPath,
	"--bundle-stats",
	"--show-require-graph",
})
assert(fs.exists(outputPath) and fs.type(outputPath) == "file", `native build did not produce {outputPath}`)

-- Lute bundles ~/.loom/store only from a checkout under the home directory. Anywhere else the compile still
-- succeeds, but the binary fails on its first require, so run it here to catch that before anything ships it.
local smoke = process.run({ outputPath, "--help" })
assert(
	smoke.ok,
	`{outputPath} failed to start: {smoke.stderr}; Lute only bundles ~/.loom/store from a checkout under the home directory`
)
