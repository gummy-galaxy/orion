local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- Shared fixtures for specs.
local testing = {}

local sequence = 0

function testing.directory(name: string): string
	sequence += 1
	local dir = tostring(path.join(system.tmpdir(), `orion-spec-{process.pid()}-{sequence}-{name}`))
	if fs.exists(dir) then
		fs.removeDirectory(dir, { recursive = true })
	end
	return dir
end

function testing.task(id: string, label: string, status: string, parentId: string?, extra: json.Object?): Item
	local data = json.object({ kind = "task", label = label, itemKind = "step", status = status })
	for key, value in extra or {} do
		data[key] = value
	end
	return { id = id, type = "task", position = { x = 0, y = 0 }, parentId = parentId, data = data }
end

function testing.group(id: string, label: string, parentId: string?): Item
	return {
		id = id,
		type = "cluster",
		position = { x = 0, y = 0 },
		parentId = parentId,
		width = 400,
		height = 200,
		data = json.object({ kind = "cluster", label = label }),
	}
end

function testing.doc(nodes: { Item }, links: { { string } }?): Doc
	local out = {}
	for _, pair in links or {} do
		table.insert(out, { id = `{pair[1]}>{pair[2]}`, from = pair[1], to = pair[2], kind = pair[3] or "blocks" })
	end
	return {
		version = 1,
		revision = 0,
		settings = { githubOwner = "flipbook-labs", sources = {} },
		nodes = nodes,
		links = out,
	}
end

function testing.result(ok: boolean, stdout: string): types.CommandResult
	return { ok = ok, exitCode = if ok then 0 else 1, stdout = stdout, stderr = "" }
end

return testing
