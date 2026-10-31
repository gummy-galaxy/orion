local json = require("@std/json")

local requestTelemetryAsync = require("@root/telemetry/requestTelemetryAsync")
local telemetryTypes = require("@root/telemetry/types")

type Limits = telemetryTypes.Limits

local function isCount(value: unknown): boolean
	return type(value) == "number" and value >= 1 and value == math.floor(value)
end

--[[
	Asks the backend how big a batch it takes, from the `config` endpoint beside
	the one events are sent to. Returns nil, and why, when it can't be reached
	or answers with something that isn't a pair of limits, so the caller can
	keep the ones it has.
]]
local function getTelemetryConfigAsync(eventsEndpoint: string, timeoutSeconds: number): (Limits?, string?)
	local configEndpoint = eventsEndpoint:gsub("/events$", "/config")
	local response, failure = requestTelemetryAsync(configEndpoint, { method = "GET" }, timeoutSeconds)

	if not response then
		return nil, failure
	end

	if not response.ok then
		return nil, `the backend answered {response.status}`
	end

	local didParse, config = pcall(json.deserialize, response.body)
	local limits = if didParse and type(config) == "table" then (config :: any).limits else nil

	if type(limits) ~= "table" or not isCount(limits.maxEvents) or not isCount(limits.maxBytes) then
		return nil, "the backend's config has no batch limits"
	end

	return { maxEvents = limits.maxEvents, maxBytes = limits.maxBytes }, nil
end

return getTelemetryConfigAsync
