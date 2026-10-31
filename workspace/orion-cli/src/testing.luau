local fs = require("@std/fs")
local json = require("@std/json")
local lintTypes = require("@std/commands/lint/types")
local path = require("@std/path")
local process = require("@std/process")
local syntax = require("@std/syntax")
local system = require("@std/system")

local cli = require("@root/cli")
local encodeStableJson = require("@root/storage/files/encodeStableJson")
local ensureDirectory = require("@root/common/platform/ensureDirectory")
local githubTypes = require("@root/sources/github/types")
local readCanvasFiles = require("@root/storage/files/readCanvasFiles")
local types = require("@root/types")
local writeCanvasFiles = require("@root/storage/files/writeCanvasFiles")
local writeDoc = require("@root/storage/canvases/writeDoc")

type Doc = types.Doc
type Item = types.Item
type PullState = githubTypes.PullState

local CLAUDE_SESSION = "0b6c3a9e-1111-4222-8333-944455556666"

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
		version = 3,
		revision = 0,
		settings = { sources = {}, checkSnoozes = {} },
		nodes = nodes,
		links = output,
		placements = {},
	}
end

-- Writes a whole canvas given as one JSON text, the way an older `orion.json`
-- held it, as a canvas folder's files.
function testing.writeCanvasText(dir: string, text: string)
	ensureDirectory(dir)
	writeCanvasFiles(dir, json.asObject(json.deserialize(text) :: json.Value) :: json.Object, nil)
end

-- A canvas folder's files joined into one stable JSON text, so a spec can
-- search them or check they didn't change.
function testing.readCanvasText(dir: string): string
	local snapshot = assert(readCanvasFiles(dir), `no canvas in {dir}`)
	return encodeStableJson(snapshot.document)
end

-- Whether an id is a random one, as `createId` makes for new nodes and links.
function testing.isRandomId(id: unknown): boolean
	return type(id) == "string"
		and id:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
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

-- Lints `source` with one rule and returns the line each violation starts on.
function testing.getLintedLines(rule: lintTypes.LintRule, source: string): { number }
	local violations = rule.lint(syntax.parse(source).root, nil, { globals = {}, options = {} })
	local lines: { number } = {}

	for _, violation in violations do
		table.insert(lines, violation.location.beginLine)
	end

	return lines
end

function testing.createHarness(name: string)
	local dir = testing.directory(name)
	writeDoc(
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

	local function setWorkspace(canvas: string)
		workspace = canvas
	end

	local function run(args: { string }, runner: types.CommandRunner?)
		return testing.run(dir, args, runner, nil, workspace)
	end

	return dir, run, setWorkspace
end

-- A Claude Code data folder with one transcript and, with a status, the
-- record of the process running it. Returns the session id.
function testing.writeClaudeFixture(dir: string, fixture: { branch: string, stop: string, status: string? }): string
	fs.createDirectory(`{dir}/projects/-work`, { makeParents = true })
	fs.writeStringToFile(
		`{dir}/projects/-work/{CLAUDE_SESSION}.jsonl`,
		`\{"type":"user","gitBranch":"{fixture.branch}","cwd":"/work","message":\{"content":"Go"}}\n`
			.. `\{"type":"assistant","gitBranch":"{fixture.branch}","cwd":"/work",`
			.. `"message":\{"stop_reason":"{fixture.stop}","content":[\{"type":"text","text":"On it."}]}}\n`
	)

	if fixture.status then
		fs.createDirectory(`{dir}/sessions`, { makeParents = true })
		fs.writeStringToFile(
			`{dir}/sessions/42.json`,
			json.serialize(
				json.object({ pid = 42, sessionId = CLAUDE_SESSION, status = fixture.status, name = "Fix the bug" })
			)
		)
		-- Key files sit beside the records and must never be read.
		fs.writeStringToFile(`{dir}/sessions/42.secret.key`, "not json")
	end

	return CLAUDE_SESSION
end

return testing
