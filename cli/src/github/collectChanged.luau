local collectPulls = require("@root/github/collectPulls")
local fetchChecks = require("@root/github/fetchChecks")
local fetchUpdated = require("@root/github/fetchUpdated")
local findRef = require("@root/refs/findRef")
local getKey = require("@root/github/getKey")
local getRefFor = require("@root/github/getRefFor")
local getString = require("@root/github/getString")
local githubTypes = require("@root/github/types")
local isInSources = require("@root/github/isInSources")
local json = require("@std/json")
local pollNotifications = require("@root/github/pollNotifications")
local types = require("@root/types")

type Ref = githubTypes.Ref
type Fetched = githubTypes.Fetched
type PollState = githubTypes.PollState
type Want = githubTypes.Want
type Doc = types.Doc
type CommandRunner = types.CommandRunner

export type Changes = { fetched: Fetched?, failures: { string }, refetched: number }

-- Whether the authored list would leave the recorded unplaced list as it is: the same pull requests, none updated.
local function isUnplacedCurrent(
	doc: Doc,
	authored: { githubTypes.PullState },
	onCanvas: { [string]: boolean }
): boolean
	local recorded = json.asObject(doc.github)
	local previous: { [string]: string } = {}
	local count = 0

	for _, raw in (if recorded then json.asArray(recorded.unplaced) else nil) or {} do
		local entry = json.asObject(raw)
		local repo = if entry then getString(entry.repo) else nil

		if entry and repo then
			previous[string.lower(`{repo}#{entry.number}`)] = getString(entry.updatedAt) or ""
			count += 1
		end
	end

	for _, pull in authored do
		local key = getKey(pull)

		if onCanvas[key] or not isInSources(doc, pull) then
			continue
		end

		if previous[key] ~= pull.updatedAt then
			return false
		end

		count -= 1
	end

	return count == 0
end

-- Whether the checks fetched for a pull request differ from the ones its card recorded.
local function hasChecksMoved(details: json.Object, pull: githubTypes.PullState): boolean
	local counts = json.asObject(details.checkCounts)
	local fetched = pull.checkCounts

	return details.checks ~= pull.checks
		or details.checkProgress ~= pull.checkProgress
		or details.head ~= pull.head
		or (
			if counts and fetched
				then counts.total ~= fetched.total or counts.finished ~= fetched.finished or counts.failed ~= fetched.failed
				else counts ~= nil or fetched ~= nil
		)
end

--[[
	Fetches only the pull request cards that changed. Notifications name the ones other people touched, polled with
	`If-Modified-Since` so an unchanged poll is free, and `poll` keeps each host's newest notification time between
	calls. A `sweep` also compares every open card's `updatedAt` with the recorded one, which catches the viewer's own
	activity, and lists the viewer's open pull requests to attach new ones by branch. `checks` reads only the checks of
	cards whose recorded checks are pending, since a finished check run moves neither. `fetched` is nil when nothing
	changed, so the caller can skip writing.
]]
local function collectChanged(doc: Doc, run: CommandRunner, poll: PollState, want: Want): Changes
	local sweep = want.sweep
	local cards: { [string]: string } = {}
	local onCanvas: { [string]: boolean } = {}
	local refs: { Ref } = {}
	local pending: { Ref } = {}
	local pendingDetails: { [string]: json.Object } = {}
	local hosts: { [string]: boolean } = {}
	local keys: { [string]: boolean } = {}
	local failures: { string } = {}

	for _, item in doc.nodes do
		local ref = getRefFor(item)

		if not ref then
			continue
		end

		local key = getKey(ref)
		local recorded = findRef(item, "pull")
		onCanvas[key] = true

		if cards[key] or (recorded and recorded.status == "merged") then
			continue
		end

		cards[key] = if recorded then recorded.updatedAt or "" else ""
		hosts[ref.host or "github.com"] = true
		table.insert(refs, ref)
		local checks = if recorded then json.asObject(recorded.checks) else nil

		if recorded and recorded.details and checks and checks.state == "pending" and recorded.status ~= "closed" then
			table.insert(pending, ref)
			pendingDetails[key] = recorded.details
		end
	end

	local interval = 0

	for host in if want.notifications then hosts else {} do
		local didPoll, result = pcall(pollNotifications, run, host, poll.lastModified[host])

		if not didPoll then
			table.insert(failures, `notifications on {host}: {result}`)
			continue
		end

		poll.lastModified[host] = result.lastModified
		interval = math.max(interval, result.interval)

		for _, ref in result.pulls do
			local key = getKey(ref)

			if cards[key] then
				keys[key] = true
			end
		end
	end

	if interval > 0 then
		poll.interval = interval
	end

	if sweep then
		local updated = fetchUpdated(run, refs)
		table.move(updated.failures, 1, #updated.failures, #failures + 1, failures)

		for key, updatedAt in updated.updatedAt do
			if cards[key] ~= updatedAt then
				keys[key] = true
			end
		end
	end

	if want.checks and #pending > 0 then
		local checked = fetchChecks(run, pending)
		table.move(checked.failures, 1, #checked.failures, #failures + 1, failures)

		for key, pull in checked.pulls do
			if hasChecksMoved(pendingDetails[key], pull) then
				keys[key] = true
			end
		end
	end

	local refetched = 0

	for _ in keys do
		refetched += 1
	end

	if refetched == 0 and not sweep then
		return { fetched = nil, failures = failures, refetched = 0 }
	end

	local fetched = collectPulls(doc, run, false, { keys = keys, listAuthored = sweep })
	table.move(failures, 1, #failures, #fetched.failures + 1, fetched.failures)

	if
		next(fetched.pulls) == nil and (fetched.authored == nil or isUnplacedCurrent(doc, fetched.authored, onCanvas))
	then
		return { fetched = nil, failures = fetched.failures, refetched = refetched }
	end

	return { fetched = fetched, failures = fetched.failures, refetched = refetched }
end

return collectChanged
