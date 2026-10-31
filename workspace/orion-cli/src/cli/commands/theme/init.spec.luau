local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local testing = require("@root/testing")

local DUSK = [[{
  "name": "Dusk",
  "light": { "canvas.background": "#f6f1ea", "canvas.glow": "#fff" },
  "dark": { "canvas.background": "#1c1726" }
}]]

test.case("theme add copies a usable file into the themes folder and warns about unknown tokens", function(assert)
	local root, run = testing.createHarness("theme-add")
	local sources = testing.directory("theme-sources")
	fs.createDirectory(sources, { makeParents = true })
	local source = path.join(sources, "dusk.json")
	fs.writeStringToFile(source, DUSK)

	local output = run({ "theme", "add", tostring(source) })

	assert.strContains(output, "Added theme Dusk as dusk.json")
	assert.strContains(output, "Warning: Ignored unknown token canvas.glow in light")
	assert.eq(fs.readFileToString(path.join(root, "themes", "dusk.json")), DUSK)
	assert.strContains(run({ "theme", "list" }), "dusk.json  Dusk  ok")
	assert.strContains(run({ "theme", "add", tostring(source) }), "Replaced theme file dusk.json with Dusk")
end)

test.case("theme add refuses a malformed file and copies nothing", function(assert)
	local root, run = testing.createHarness("theme-add-broken")
	local sources = testing.directory("theme-broken-sources")
	fs.createDirectory(sources, { makeParents = true })
	local source = path.join(sources, "bad.json")
	fs.writeStringToFile(source, '{"dark":{"canvas.background":"url(https://example.com/a.png)"}}')

	assert.throwsWith("bad.json dark canvas.background uses url(), which a color cannot", function()
		run({ "theme", "add", tostring(source) })
	end)
	assert.eq(fs.exists(path.join(root, "themes")), false)

	local notJson = path.join(sources, "notes.txt")
	fs.writeStringToFile(notJson, DUSK)

	assert.throwsWith("a theme file must be a .json file", function()
		run({ "theme", "add", tostring(notJson) })
	end)
end)

test.case("theme list marks files that cannot be used, and theme remove deletes one", function(assert)
	local root, run = testing.createHarness("theme-list")
	fs.createDirectory(path.join(root, "themes"), { makeParents = true })
	fs.writeStringToFile(path.join(root, "themes", "bad.json"), "{")
	fs.writeStringToFile(path.join(root, "themes", "dusk.json"), DUSK)

	assert.strContains(run({ "theme", "list" }), "bad.json  bad  broken: is not valid JSON")
	assert.strContains(run({ "theme", "list", "--json" }), '"file": "bad.json"')

	assert.eq(run({ "theme", "remove", "bad.json" }), "Removed theme bad.json")
	assert.eq(fs.exists(path.join(root, "themes", "bad.json")), false)

	assert.throwsWith("no theme file named bad.json", function()
		run({ "theme", "remove", "bad.json" })
	end)
	assert.throwsWith("name a theme file, not a path", function()
		run({ "theme", "remove", "../dusk.json" })
	end)
end)

test.case("theme list says so when there are no theme files", function(assert)
	local _, run = testing.createHarness("theme-empty")

	assert.eq(run({ "theme", "list" }), "No theme files.")
end)
