local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local store = require("@root/store")
local testing = require("@root/testing")

test.case("workspace create and list use a temporary data root", function(assert)
	local root, run = testing.createHarness("workspace-create")
	local initial = json.asObject(json.deserialize(run({ "workspace", "list", "--json" })) :: json.Value)
	assert.eq(initial and initial.active, "default")
	assert.eq(initial and #(json.asArray(initial.workspaces) or {}), 1)
	run({ "workspace", "create", "roblox", "--label", "Roblox" })
	local dir = tostring(path.join(root, "workspaces", "roblox"))
	local doc = store.load(dir)
	assert.eq(doc.version, 2)
	assert.eq(doc.revision, 0)
	assert.eq(#doc.settings.sources, 0)
	assert.eq(#doc.nodes, 0)
	assert.eq(#doc.links, 0)
	local listed = json.asObject(json.deserialize(run({ "workspace", "list", "--json" })) :: json.Value)
	local entries = if listed then json.asArray(listed.workspaces) else nil
	assert.eq(listed and listed.active, "default")
	assert.eq(entries and #entries, 2)
	local second = if entries then json.asObject(entries[2]) else nil
	assert.eq(second and second.label, "Roblox")
	assert.eq(run({ "path", "--workspace", "roblox" }), dir)
	assert.eq(run({ "--workspace", "roblox", "path" }), dir)
	assert.eq(run({ "path" }), root)
	assert.throwsWith("workspace already exists: roblox", function()
		run({ "workspace", "create", "roblox" })
	end)

	assert.throwsWith("invalid workspace name: Bad/Name", function()
		run({ "workspace", "create", "Bad/Name" })
	end)
end)

test.case("workspace rename changes only the label", function(assert)
	local root, run = testing.createHarness("workspace-rename")
	run({ "workspace", "create", "focus", "--label", "Focus areas" })
	run({ "workspace", "use", "focus" })
	assert.eq(
		run({ "workspace", "rename", "focus", "Foundation components" }),
		"Renamed workspace focus to Foundation components"
	)
	local listed = json.asObject(json.deserialize(run({ "workspace", "list", "--json" })) :: json.Value)
	local entries = if listed then json.asArray(listed.workspaces) else nil
	local second = if entries then json.asObject(entries[2]) else nil
	assert.eq(listed and listed.active, "focus")
	assert.eq(second and second.name, "focus")
	assert.eq(second and second.label, "Foundation components")
	assert.eq(run({ "path" }), tostring(path.join(root, "workspaces", "focus")))
	run({ "workspace", "rename", "default", "Personal" })
	local relisted = json.asObject(json.deserialize(run({ "workspace", "list", "--json" })) :: json.Value)
	local first = if relisted then json.asObject((json.asArray(relisted.workspaces) or {})[1]) else nil
	assert.eq(first and first.label, "Personal")

	assert.throwsWith("unknown workspace: missing", function()
		run({ "workspace", "rename", "missing", "Missing" })
	end)

	assert.throwsWith("label must be nonempty", function()
		run({ "workspace", "rename", "focus", "  " })
	end)
end)

test.case("workspace selection follows option, environment, manifest, default", function(assert)
	local root, run, setWorkspace = testing.createHarness("workspace-use")
	assert.eq(run({ "workspace", "current" }), "default")
	run({ "workspace", "create", "roblox" })
	run({ "workspace", "create", "docs" })
	run({ "workspace", "use", "roblox" })
	assert.eq(run({ "workspace", "current" }), "roblox")
	assert.eq(run({ "path" }), tostring(path.join(root, "workspaces", "roblox")))
	setWorkspace("docs")
	assert.eq(run({ "workspace", "current" }), "docs")
	local listed = json.asObject(json.deserialize(run({ "workspace", "list", "--json" })) :: json.Value)
	assert.eq(listed and listed.active, "docs")
	assert.eq(run({ "path", "--workspace", "roblox" }), tostring(path.join(root, "workspaces", "roblox")))
	local overridden =
		json.asObject(json.deserialize(run({ "workspace", "list", "--json", "--workspace", "roblox" })) :: json.Value)
	assert.eq(overridden and overridden.active, "roblox")
	setWorkspace("")
	assert.throwsWith("unknown workspace: missing", function()
		run({ "workspace", "use", "missing" })
	end)

	assert.throwsWith("unknown workspace: missing", function()
		run({ "path", "--workspace", "missing" })
	end)
end)

test.case("workspace set stores the canvas cover and background and needs an image it holds", function(assert)
	local root, run = testing.createHarness("workspace-style")
	assert.throwsWith("give --cover or --background", function()
		run({ "workspace", "set" })
	end)
	assert.throws(function()
		run({ "workspace", "set", "--cover", "image-missing.png" })
	end)
	fs.createDirectory(path.join(root, "assets"), { makeParents = true })
	fs.writeStringToFile(path.join(root, "assets", "image-logo.png"), "bytes")
	run({ "workspace", "set", "--cover", "image-logo.png", "--background", "canvas.background" })
	local doc = store.load(root)
	assert.eq(doc.settings.cover, "image-logo.png")
	assert.eq(doc.settings.background, "canvas.background")
	assert.eq(doc.revision, 1)
	run({ "workspace", "set", "--cover", "" })
	assert.eq(store.load(root).settings.cover, nil)
end)

-- Lists workspace names in the order the command reports them.
local function listNames(output: string): string
	local listed = assert(json.asObject(json.deserialize(output) :: json.Value), "expected a workspace list")
	local names: { string } = {}

	for _, entry in json.asArray(listed.workspaces) or {} do
		local object = json.asObject(entry)
		table.insert(names, if object then tostring(object.name) else "")
	end

	return table.concat(names, ",")
end

test.case("workspace create derives the name from a label when none is given", function(assert)
	local root, run = testing.createHarness("workspace-derive")
	assert.eq(run({ "workspace", "create", "--label", "Focus areas" }), "Created workspace focus-areas")
	assert.eq(listNames(run({ "workspace", "list", "--json" })), "default,focus-areas")
	assert.eq(run({ "path", "--workspace", "focus-areas" }), tostring(path.join(root, "workspaces", "focus-areas")))

	local listed = json.asObject(json.deserialize(run({ "workspace", "list", "--json" })) :: json.Value)
	local entries = if listed then json.asArray(listed.workspaces) else nil
	local second = if entries then json.asObject(entries[2]) else nil
	assert.eq(second and second.label, "Focus areas")

	assert.throwsWith("workspace already exists: focus-areas", function()
		run({ "workspace", "create", "--label", "focus areas" })
	end)

	assert.throwsWith("give a name or a label", function()
		run({ "workspace", "create" })
	end)

	assert.throwsWith("pass a name: the label has no letters or digits to derive one from", function()
		run({ "workspace", "create", "--label", "!!!" })
	end)

	assert.throwsWith("invalid workspace name: Focus areas", function()
		run({ "workspace", "create", "Focus areas" })
	end)
end)

test.case("workspace archive hides a workspace and restore brings it back with its data", function(assert)
	local root, run = testing.createHarness("workspace-archive")
	run({ "workspace", "create", "docs" })
	run({ "workspace", "create", "roblox" })
	run({ "--workspace", "roblox", "add", "Kept on the canvas" })
	local dir = tostring(path.join(root, "workspaces", "roblox"))
	assert.eq(#store.load(dir).nodes, 1)

	assert.eq(run({ "workspace", "archive", "roblox" }), "Archived workspace roblox")
	assert.eq(listNames(run({ "workspace", "list", "--json" })), "default,docs")
	assert.eq(listNames(run({ "workspace", "list", "--archived", "--json" })), "roblox")
	assert.eq(#store.load(dir).nodes, 1)

	assert.throwsWith("unknown workspace: roblox", function()
		run({ "workspace", "use", "roblox" })
	end)

	assert.throwsWith("workspace already archived: roblox", function()
		run({ "workspace", "archive", "roblox" })
	end)

	assert.throwsWith(`workspace folder already exists: {dir}`, function()
		run({ "workspace", "create", "roblox" })
	end)

	assert.eq(run({ "workspace", "restore", "roblox" }), "Restored workspace roblox")
	assert.eq(listNames(run({ "workspace", "list", "--json" })), "default,docs,roblox")
	assert.eq(listNames(run({ "workspace", "list", "--archived", "--json" })), "")
	assert.eq(#store.load(dir).nodes, 1)

	assert.throwsWith("unknown archived workspace: roblox", function()
		run({ "workspace", "restore", "roblox" })
	end)
end)

test.case("workspace archive refuses the active, default, and unknown workspaces", function(assert)
	local _, run = testing.createHarness("workspace-archive-refuse")
	run({ "workspace", "create", "docs" })
	run({ "workspace", "use", "docs" })

	assert.throwsWith("can't archive the active workspace: docs", function()
		run({ "workspace", "archive", "docs" })
	end)

	assert.throwsWith("can't archive the active workspace: docs", function()
		run({ "workspace", "use", "default" })
		run({ "workspace", "use", "docs" })
		run({ "workspace", "archive", "docs", "--workspace", "docs" })
	end)

	run({ "workspace", "use", "default" })

	assert.throwsWith("the default workspace can't be archived", function()
		run({ "workspace", "archive", "default" })
	end)

	assert.throwsWith("unknown workspace: missing", function()
		run({ "workspace", "archive", "missing" })
	end)

	assert.eq(listNames(run({ "workspace", "list", "--json" })), "default,docs")
end)
