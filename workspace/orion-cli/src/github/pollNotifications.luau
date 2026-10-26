local getKey = require("@root/github/getKey")
local githubTypes = require("@root/github/types")
local json = require("@std/json")
local types = require("@root/types")

type Ref = githubTypes.Ref
type CommandRunner = types.CommandRunner

export type Poll = {
	-- False when GitHub answered 304, which doesn't count against the rate
	-- limit.
	changed: boolean,
	-- The newest notification's time, sent back as `If-Modified-Since` on the
	-- next poll.
	lastModified: string?,
	-- Seconds GitHub asks clients to wait before polling again.
	interval: number,
	pulls: { Ref },
}

local DEFAULT_INTERVAL = 60
local PAGE_SIZE = 100
local MONTHS = {
	Jan = "01",
	Feb = "02",
	Mar = "03",
	Apr = "04",
	May = "05",
	Jun = "06",
	Jul = "07",
	Aug = "08",
	Sep = "09",
	Oct = "10",
	Nov = "11",
	Dec = "12",
}

-- Turns an HTTP date such as `Sun, 18 Oct 2026 15:53:33 GMT` into the ISO 8601
-- time the `since` parameter takes.
local function toIso(httpDate: string): string?
	local day, month, year, time = httpDate:match("(%d+) (%a+) (%d+) (%d+:%d+:%d+)")
	local monthNumber = if month then MONTHS[month] else nil

	if not monthNumber then
		return nil
	end

	return `{year}-{monthNumber}-{string.format("%02d", tonumber(day) :: number)}T{time}Z`
end

-- Splits `gh api --include` output into its status code, lowercased headers,
-- and body.
local function parseResponse(output: string): (number?, { [string]: string }, string)
	local headers: { [string]: string } = {}
	local status: number? = nil
	local position = 1

	while position <= #output do
		local lineEnd = output:find("\n", position, true) or #output + 1
		local line = output:sub(position, lineEnd - 1):gsub("\r$", "")
		position = lineEnd + 1

		if line == "" then
			break
		elseif not status then
			status = tonumber(line:match("^HTTP/%S+ (%d+)"))
		else
			local name, value = line:match("^([^:]+):%s*(.*)$")

			if name then
				headers[name:lower()] = value
			end
		end
	end

	return status, headers, output:sub(position)
end

local function getPullRef(raw: json.Value, host: string): Ref?
	local notification = json.asObject(raw)
	local subject = if notification then json.asObject(notification.subject) else nil
	local url = if subject and subject.type == "PullRequest" then subject.url else nil

	if type(url) ~= "string" then
		return nil
	end

	local owner, name, number = url:match("/repos/([^/]+)/([^/]+)/pulls/(%d+)$")

	if not owner or not name then
		return nil
	end

	return {
		owner = owner,
		name = name,
		number = tonumber(number) :: number,
		host = if host == "github.com" then nil else host,
	}
end

--[[
	Polls the viewer's notifications on `host` for pull requests that changed
	since `lastModified`. Notifications cover reviews, comments, review
	requests, and state changes by other people, never the viewer's own
	activity. Without `lastModified`, the poll only records the newest
	notification's time, since a full refresh covers everything before it. A
	poll that names more than a page of pull requests keeps the first page; the
	light sweep catches the rest.
]]
local function pollNotifications(run: CommandRunner, host: string, lastModified: string?): Poll
	local since = if lastModified then toIso(lastModified) else nil
	local argv = { "gh", "api", "--include" }

	if host ~= "github.com" then
		table.insert(argv, "--hostname")
		table.insert(argv, host)
	end

	if lastModified then
		table.insert(argv, "--header")
		table.insert(argv, `If-Modified-Since: {lastModified}`)
	end

	table.insert(
		argv,
		if since
			then `/notifications?all=true&per_page={PAGE_SIZE}&since={since}`
			else "/notifications?all=true&per_page=1"
	)

	-- gh exits non-zero on a 304, so the status line decides, not the exit
	-- code.
	local response = run(argv, nil)
	local status, headers, body = parseResponse(response.stdout)
	local interval = tonumber(headers["x-poll-interval"]) or DEFAULT_INTERVAL

	if status == 304 then
		return {
			changed = false,
			lastModified = lastModified or headers["last-modified"],
			interval = interval,
			pulls = {},
		}
	end

	assert(status == 200, `gh api notifications failed: {response.stderr:match("[^\r\n]+") or status}`)

	local pulls: { Ref } = {}
	local seen: { [string]: boolean } = {}

	if since then
		local decodedOk, decoded = pcall(json.deserialize, body)

		for _, raw in (if decodedOk then json.asArray(decoded :: json.Value) else nil) or {} do
			local ref = getPullRef(raw, host)
			local key = if ref then getKey(ref) else nil

			if ref and key and not seen[key] then
				seen[key] = true
				table.insert(pulls, ref)
			end
		end
	end

	return {
		changed = lastModified ~= nil,
		lastModified = headers["last-modified"] or lastModified,
		interval = interval,
		pulls = pulls,
	}
end

return pollNotifications
