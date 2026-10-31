local getKey = require("@root/github/getKey")
local getString = require("@root/github/getString")
local githubTypes = require("@root/github/types")
local json = require("@std/json")
local queryAsync = require("@root/github/queryAsync")
local types = require("@root/types")

type CheckRun = githubTypes.CheckRun
type PullState = githubTypes.PullState
type CommandRunner = types.CommandRunner

local BATCH_SIZE = 25
local NAME_PATTERN = "^[%w%-%._]+$"

-- The conclusions and states that fail a job match getCheckCounts, so a job
-- counts the same way in both.
local CHECK_RUN_STATES: { [string]: "failed" | "passed" } = {
	FAILURE = "failed",
	TIMED_OUT = "failed",
	STARTUP_FAILURE = "failed",
	ACTION_REQUIRED = "failed",
	SUCCESS = "passed",
}
local STATUS_CONTEXT_STATES: { [string]: "failed" | "passed" | "pending" } = {
	FAILURE = "failed",
	ERROR = "failed",
	SUCCESS = "passed",
	PENDING = "pending",
	EXPECTED = "pending",
}

local function getContexts(number: number): string
	return `contexts(first: 100) \{ nodes \{ __typename ... on CheckRun \{ name status conclusion `
		.. `isRequired(pullRequestNumber: {number}) } ... on StatusContext \{ context state `
		.. `isRequired(pullRequestNumber: {number}) } } }`
end

local function parseRun(node: json.Object): CheckRun?
	local required = node.isRequired == true

	if node.__typename == "CheckRun" then
		local name = getString(node.name)
		local conclusion = getString(node.conclusion)

		if not name then
			return nil
		end

		local state: "failed" | "passed" | "pending" | "other" = if conclusion == nil
			then "pending"
			else CHECK_RUN_STATES[conclusion] or "other"
		return { name = name, state = state, required = required }
	elseif node.__typename == "StatusContext" then
		local name = getString(node.context)
		local state = getString(node.state)

		if not name or not state then
			return nil
		end

		return { name = name, state = STATUS_CONTEXT_STATES[state] or "other", required = required }
	end

	return nil
end

-- Lists every job on each pull request's head commit, keyed like
-- fetchPullsAsync. Asking whether a job is required needs the pull request's
-- number, which is why this is a second query rather than part of the fields
-- fetchPullsAsync reads.
local function fetchCheckRunsAsync(run: CommandRunner, pulls: { PullState }): { [string]: { CheckRun } }
	local found: { [string]: { CheckRun } } = {}
	local byHost: { [string]: { PullState } } = {}

	for _, pull in pulls do
		local host = pull.host or "github.com"
		byHost[host] = byHost[host] or {}
		table.insert(byHost[host], pull)
	end

	for host, hostPulls in byHost do
		for start = 1, #hostPulls, BATCH_SIZE do
			local parts = {}
			local batch: { [string]: PullState } = {}

			for index = start, math.min(start + BATCH_SIZE - 1, #hostPulls) do
				local pull = hostPulls[index]
				assert(
					pull.owner:match(NAME_PATTERN) and pull.name:match(NAME_PATTERN),
					`invalid repository {pull.owner}/{pull.name}`
				)
				local alias = `c{index}`
				batch[alias] = pull
				table.insert(
					parts,
					`{alias}: repository(owner: "{pull.owner}", name: "{pull.name}") \{ pullRequest(number: {pull.number}) `
						.. `\{ commits(last: 1) \{ nodes \{ commit \{ statusCheckRollup \{ {getContexts(pull.number)} `
						.. "} } } } } }"
				)
			end

			local data =
				queryAsync(run, `query \{ {table.concat(parts, " ")} }`, if host == "github.com" then nil else host)

			for alias, pull in batch do
				local repository = if data then json.asObject(data[alias]) else nil
				local pullRequest = if repository then json.asObject(repository.pullRequest) else nil
				local commits = if pullRequest then json.asObject(pullRequest.commits) else nil
				local commitNodes = if commits then json.asArray(commits.nodes) else nil
				local last = if commitNodes then json.asObject(commitNodes[1]) else nil
				local commit = if last then json.asObject(last.commit) else nil
				local rollup = if commit then json.asObject(commit.statusCheckRollup) else nil
				local contexts = if rollup then json.asObject(rollup.contexts) else nil

				if contexts then
					local runs: { CheckRun } = {}

					for _, raw in json.asArray(contexts.nodes) or {} do
						local node = json.asObject(raw)
						local parsed = if node then parseRun(node) else nil

						if parsed then
							table.insert(runs, parsed)
						end
					end

					found[getKey(pull)] = runs
				end
			end
		end
	end

	return found
end

return fetchCheckRunsAsync
