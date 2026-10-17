local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local cli = require("@root/cli")
local githubTypes = require("@root/github/types")
local store = require("@root/store")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type PullState = githubTypes.PullState

-- Shared fixtures for specs.
local testing = {}

local sequence = 0

function testing.pull(
	state: string,
	extra: { draft: boolean?, reviewDecision: string?, reviewRequests: number? }?
): PullState
	local given: { draft: boolean?, reviewDecision: string?, reviewRequests: number? } = extra or {}

	return {
		owner = "flipbook-labs",
		name = "flipbook",
		number = 1,
		state = state,
		baseRefName = "main",
		headRefName = "feature/a",
		draft = given.draft == true,
		reviewDecision = given.reviewDecision,
		reviewRequests = given.reviewRequests or 0,
		requestedReviewers = {},
		title = "Title",
		url = "https://github.com/flipbook-labs/flipbook/pull/1",
		author = "vocksel",
		updatedAt = "2026-10-04T00:00:00Z",
		additions = 12,
		deletions = 3,
		checks = "SUCCESS",
	}
end

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

function testing.createDoc(nodes: { Item }, links: { { string } }?): Doc
	local output = {}

	for _, pair in links or {} do
		table.insert(output, { id = `{pair[1]}>{pair[2]}`, from = pair[1], to = pair[2], kind = pair[3] or "blocks" })
	end

	return {
		version = 2,
		revision = 0,
		settings = { sources = {} },
		nodes = nodes,
		links = output,
	}
end

function testing.result(succeeded: boolean, stdout: string, stderr: string?): types.CommandResult
	return { ok = succeeded, exitCode = if succeeded then 0 else 1, stdout = stdout, stderr = stderr or "" }
end

function testing.run(
	dir: string,
	args: { string },
	runner: types.CommandRunner?,
	now: string?,
	workspace: string?
): string
	local output: { string } = {}
	cli.execute(args, {
		dataDir = dir,
		workspace = workspace,
		write = function(line)
			table.insert(output, line)
		end,

		runner = runner,
		now = function()
			return now or "2026-10-04T00:00:00Z"
		end,
	})
	return table.concat(output, "\n")
end

function testing.createHarness(name: string)
	local dir = testing.directory(name)
	store.write(
		dir,
		testing.createDoc({
			testing.group("ws", "Release"),
			testing.task("ci", "Report release health", "active", "ws", {
				repo = "flipbook-labs/flipbook",
				refs = { { source = "github", kind = "pull", key = "flipbook-labs/flipbook#658" } },
			}),
			testing.task("pub", "Publish v2.6.0", "todo", "ws"),
		}, { { "ci", "pub" } })
	)
	local workspace = ""

	local function setWorkspace(name: string)
		workspace = name
	end

	local function run(args: { string }, runner: types.CommandRunner?)
		return testing.run(dir, args, runner, nil, workspace)
	end

	return dir, run, setWorkspace
end

return testing
