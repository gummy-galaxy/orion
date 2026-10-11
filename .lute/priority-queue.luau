--[[
	Moves a pull request's perf job ahead of the queue on the Beelink. The Prioritize PR workflow runs each subcommand in
	turn: `add` labels the pull request, `watch` waits until its perf job starts or is skipped, and `remove` takes the
	label off again. Run them by hand with the same arguments:

		lute run priority-queue add --pr <n>
		lute run priority-queue watch --pr <n>
		lute run priority-queue remove --pr <n>

	The repository defaults to GITHUB_REPOSITORY, or pass --repo owner/name.
]]
local cli = require("@batteries/cli")
local process = require("@std/process")

local addPriorityLabel = require("@lib/addPriorityLabel")
local label = require("@lib/label")
local removePriorityLabel = require("@lib/removePriorityLabel")
local watchPerfJob = require("@lib/watchPerfJob")

local root = cli.parser()

local function addSubcommand(name: string, help: string)
	local subcommand = root:subcommand(name, { help = help })

	subcommand:add("pr", "option", { help = "Pull request number", required = true })
	subcommand:add("repo", "option", { help = "Repository, as owner/name. Defaults to GITHUB_REPOSITORY" })
end

addSubcommand("add", `Add the {label.NAME} label to a pull request`)
addSubcommand("watch", "Wait until the pull request's perf job starts, is skipped, or never queues")
addSubcommand("remove", `Remove the {label.NAME} label from a pull request`)

-- Lute passes the program path as the first argument.
root:parse({ table.unpack({ ... }, 2) })

local command, subcommand = root:selected()

if not command or not subcommand then
	error("usage: lute run priority-queue <add|watch|remove> --pr <n> [--repo owner/name]", 0)
end

local pullRequest = assert(subcommand:get("pr"), "--pr is required")
assert(string.match(pullRequest, "^%d+$"), `--pr must be a pull request number, got {pullRequest}`)

local repository = subcommand:get("repo") or process.env.GITHUB_REPOSITORY
assert(repository, "pass --repo owner/name or set GITHUB_REPOSITORY")

if command == "add" then
	addPriorityLabel(repository, pullRequest)
	print(`Added {label.NAME} to PR #{pullRequest}`)
elseif command == "watch" then
	watchPerfJob(repository, pullRequest)
else
	removePriorityLabel(repository, pullRequest)
	print(`Removed {label.NAME} from PR #{pullRequest}`)
end
