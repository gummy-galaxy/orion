--[[
	Records CI's perf run in PostHog so results can be charted across commits. It reads app/.perf/raw.json and sends
	one `perf_run` event per side. Without a PostHog token, or when PostHog refuses or can't be reached, it warns and
	leaves the job alone.
]]
local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@std/net")
local path = require("@std/path")
local process = require("@std/process")

local getPerfEvents = require("@root/perf/getPerfEvents")
local runScript = require("@root/runScript")

local DEFAULT_HOST = "https://us.i.posthog.com"
local DISTINCT_ID = "orion-ci"

local env = process.env
local rawPath = path.resolve("../app/.perf/raw.json")

local function warn(message: string)
	print(`::warning title=Perf history::{message}`)
end

runScript(function()
	local token = env.POSTHOG_TOKEN

	if token == nil or token == "" then
		warn("POSTHOG_TOKEN isn't set, so this run isn't recorded.")
		return
	end

	if not fs.exists(rawPath) then
		warn("app/.perf/raw.json is missing, so this run isn't recorded.")
		return
	end

	local raw = json.asObject(json.deserialize(fs.readFileToString(rawPath)) :: json.Value)
	assert(raw, "raw.json must hold an object")

	local events = getPerfEvents(raw, {
		eventName = env.GITHUB_EVENT_NAME or "unknown",
		pullRequest = tonumber(env.PR or ""),
		runner = env.RUNNER_NAME,
		runUrl = env.RUN_URL,
	})

	if #events == 0 then
		warn("raw.json has no measurements, so this run isn't recorded.")
		return
	end

	local batch = {}

	for _, event in events do
		-- Runs aren't people, so there's no profile to build.
		event.properties["$process_person_profile"] = false

		table.insert(
			batch,
			json.object({ event = event.event, distinct_id = DISTINCT_ID, properties = event.properties })
		)
	end

	local host = if env.POSTHOG_HOST and env.POSTHOG_HOST ~= "" then env.POSTHOG_HOST else DEFAULT_HOST
	local body = json.serialize(json.object({ api_key = token, batch = batch }))
	local metadata: net.Metadata = {
		method = "POST",
		headers = { ["Content-Type"] = "application/json" },
		body = body,
	}
	local sent, response = pcall(net.request, `{host}/batch/`, metadata)

	if not sent then
		warn(`PostHog couldn't be reached: {tostring(response)}`)
		return
	end

	if not response.ok then
		warn(`PostHog refused the run with {response.status}: {response.body}`)
		return
	end

	print(`Recorded {#events} perf events in PostHog.`)
end)
