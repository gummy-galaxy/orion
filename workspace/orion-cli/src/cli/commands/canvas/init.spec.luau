local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local loadDoc = require("@root/storage/canvases/loadDoc")
local testing = require("@root/testing")

test.case("workspace create and list use a temporary data root", function(assert)
	local root, run = testing.createHarness("workspace-create")
	local initial = json.asObject(json.deserialize(run({ "canvas", "list", "--json" })) :: json.Value)
	assert.eq(initial and initial.active, "default")
	assert.eq(initial and #(json.asArray(initial.canvases) or {}), 1)
	run({ "canvas", "create", "roblox", "--label", "Roblox" })
	local dir = tostring(path.join(root, "canvases", "roblox"))
	local doc = loadDoc(dir)
	assert.eq(doc.version, 3)
	assert.eq(doc.revision, 0)
	assert.eq(#doc.settings.sources, 0)
	assert.eq(#doc.nodes, 0)
	assert.eq(#doc.links, 0)
	local listed = json.asObject(json.deserialize(run({ "canvas", "list", "--json" })) :: json.Value)
	local entries = if listed then json.asArray(listed.canvases) else nil
	assert.eq(listed and listed.active, "default")
	assert.eq(entries and #entries, 2)
	local second = if entries then json.asObject(entries[2]) else nil
	assert.eq(second and second.label, "Roblox")
	assert.eq(run({ "canvas", "path", "--canvas", "roblox" }), dir)
	assert.eq(run({ "--canvas", "roblox", "canvas", "path" }), dir)
	assert.eq(run({ "canvas", "path" }), root)
	assert.throwsWith("canvas already exists: roblox", function()
		run({ "canvas", "create", "roblox" })
	end)

	assert.throwsWith("invalid canvas name: Bad/Name", function()
		run({ "canvas", "create", "Bad/Name" })
	end)
end)

test.case("workspace rename changes only the label", function(assert)
	local root, run = testing.createHarness("workspace-rename")
	run({ "canvas", "create", "focus", "--label", "Focus areas" })
	run({ "canvas", "use", "focus" })
	assert.eq(
		run({ "canvas", "rename", "focus", "Foundation components" }),
		"Renamed canvas focus to Foundation components"
	)
	local listed = json.asObject(json.deserialize(run({ "canvas", "list", "--json" })) :: json.Value)
	local entries = if listed then json.asArray(listed.canvases) else nil
	local second = if entries then json.asObject(entries[2]) else nil
	assert.eq(listed and listed.active, "focus")
	assert.eq(second and second.name, "focus")
	assert.eq(second and second.label, "Foundation components")
	assert.eq(run({ "canvas", "path" }), tostring(path.join(root, "canvases", "focus")))
	run({ "canvas", "rename", "default", "Personal" })
	local relisted = json.asObject(json.deserialize(run({ "canvas", "list", "--json" })) :: json.Value)
	local first = if relisted then json.asObject((json.asArray(relisted.canvases) or {})[1]) else nil
	assert.eq(first and first.label, "Personal")

	assert.throwsWith("unknown canvas: missing", function()
		run({ "canvas", "rename", "missing", "Missing" })
	end)

	assert.throwsWith("label must be nonempty", function()
		run({ "canvas", "rename", "focus", "  " })
	end)
end)

test.case("workspace selection follows option, environment, manifest, default", function(assert)
	local root, run, setWorkspace = testing.createHarness("workspace-use")
	assert.eq(run({ "canvas", "current" }), "default")
	run({ "canvas", "create", "roblox" })
	run({ "canvas", "create", "docs" })
	run({ "canvas", "use", "roblox" })
	assert.eq(run({ "canvas", "current" }), "roblox")
	assert.eq(run({ "canvas", "path" }), tostring(path.join(root, "canvases", "roblox")))
	setWorkspace("docs")
	assert.eq(run({ "canvas", "current" }), "docs")
	local listed = json.asObject(json.deserialize(run({ "canvas", "list", "--json" })) :: json.Value)
	assert.eq(listed and listed.active, "docs")
	assert.eq(run({ "canvas", "path", "--canvas", "roblox" }), tostring(path.join(root, "canvases", "roblox")))
	local overridden =
		json.asObject(json.deserialize(run({ "canvas", "list", "--json", "--canvas", "roblox" })) :: json.Value)
	assert.eq(overridden and overridden.active, "roblox")
	setWorkspace("")
	assert.throwsWith("unknown canvas: missing", function()
		run({ "canvas", "use", "missing" })
	end)

	assert.throwsWith("unknown canvas: missing", function()
		run({ "canvas", "path", "--canvas", "missing" })
	end)
end)

test.case("workspace set stores the canvas cover and background and needs an image it holds", function(assert)
	local root, run = testing.createHarness("workspace-style")
	assert.throwsWith("give --cover, --background, or --header", function()
		run({ "canvas", "set" })
	end)
	assert.throws(function()
		run({ "canvas", "set", "--cover", "image-missing.png" })
	end)
	fs.createDirectory(path.join(root, "assets"), { makeParents = true })
	fs.writeStringToFile(path.join(root, "assets", "image-logo.png"), "bytes")
	run({ "canvas", "set", "--cover", "image-logo.png", "--background", "canvas.background" })
	local doc = loadDoc(root)
	assert.eq(doc.settings.cover, "image-logo.png")
	assert.eq(doc.settings.background, "canvas.background")
	assert.eq(doc.revision, 1)
	run({ "canvas", "set", "--cover", "" })
	assert.eq(loadDoc(root).settings.cover, nil)
end)

-- Lists workspace names in the order the command reports them.
local function listNames(output: string): string
	local listed = assert(json.asObject(json.deserialize(output) :: json.Value), "expected a canvas list")
	local names: { string } = {}

	for _, entry in json.asArray(listed.canvases) or {} do
		local object = json.asObject(entry)
		table.insert(names, if object then tostring(object.name) else "")
	end

	return table.concat(names, ",")
end

test.case("workspace create derives the name from a label when none is given", function(assert)
	local root, run = testing.createHarness("workspace-derive")
	assert.eq(run({ "canvas", "create", "--label", "Focus areas" }), "Created canvas focus-areas")
	assert.eq(listNames(run({ "canvas", "list", "--json" })), "default,focus-areas")
	assert.eq(
		run({ "canvas", "path", "--canvas", "focus-areas" }),
		tostring(path.join(root, "canvases", "focus-areas"))
	)

	local listed = json.asObject(json.deserialize(run({ "canvas", "list", "--json" })) :: json.Value)
	local entries = if listed then json.asArray(listed.canvases) else nil
	local second = if entries then json.asObject(entries[2]) else nil
	assert.eq(second and second.label, "Focus areas")

	assert.throwsWith("canvas already exists: focus-areas", function()
		run({ "canvas", "create", "--label", "focus areas" })
	end)

	assert.throwsWith("give a name or a label", function()
		run({ "canvas", "create" })
	end)

	assert.throwsWith("pass a name: the label has no letters or digits to derive one from", function()
		run({ "canvas", "create", "--label", "!!!" })
	end)

	assert.throwsWith("invalid canvas name: Focus areas", function()
		run({ "canvas", "create", "Focus areas" })
	end)
end)

test.case("workspace archive hides a workspace and restore brings it back with its data", function(assert)
	local root, run = testing.createHarness("workspace-archive")
	run({ "canvas", "create", "docs" })
	run({ "canvas", "create", "roblox" })
	run({ "--canvas", "roblox", "card", "create", "Kept on the canvas" })
	local dir = tostring(path.join(root, "canvases", "roblox"))
	assert.eq(#loadDoc(dir).nodes, 1)

	assert.eq(run({ "canvas", "archive", "roblox" }), "Archived canvas roblox")
	assert.eq(listNames(run({ "canvas", "list", "--json" })), "default,docs")
	assert.eq(listNames(run({ "canvas", "list", "--archived", "--json" })), "roblox")
	assert.eq(#loadDoc(dir).nodes, 1)

	assert.throwsWith("unknown canvas: roblox", function()
		run({ "canvas", "use", "roblox" })
	end)

	assert.throwsWith("canvas already archived: roblox", function()
		run({ "canvas", "archive", "roblox" })
	end)

	assert.throwsWith(`canvas folder already exists: {dir}`, function()
		run({ "canvas", "create", "roblox" })
	end)

	assert.eq(run({ "canvas", "restore", "roblox" }), "Restored canvas roblox")
	assert.eq(listNames(run({ "canvas", "list", "--json" })), "default,docs,roblox")
	assert.eq(listNames(run({ "canvas", "list", "--archived", "--json" })), "")
	assert.eq(#loadDoc(dir).nodes, 1)

	assert.throwsWith("unknown archived canvas: roblox", function()
		run({ "canvas", "restore", "roblox" })
	end)
end)

test.case("workspace archive refuses the active, default, and unknown workspaces", function(assert)
	local _, run = testing.createHarness("workspace-archive-refuse")
	run({ "canvas", "create", "docs" })
	run({ "canvas", "use", "docs" })

	assert.throwsWith("can't archive the active canvas: docs", function()
		run({ "canvas", "archive", "docs" })
	end)

	assert.throwsWith("can't archive the active canvas: docs", function()
		run({ "canvas", "use", "default" })
		run({ "canvas", "use", "docs" })
		run({ "canvas", "archive", "docs", "--canvas", "docs" })
	end)

	run({ "canvas", "use", "default" })

	assert.throwsWith("the default canvas can't be archived", function()
		run({ "canvas", "archive", "default" })
	end)

	assert.throwsWith("unknown canvas: missing", function()
		run({ "canvas", "archive", "missing" })
	end)

	assert.eq(listNames(run({ "canvas", "list", "--json" })), "default,docs")
end)
