local json = require("@std/json")

local requestTelemetryAsync = require("@root/telemetry/requestTelemetryAsync")
local telemetryTypes = require("@root/telemetry/types")

type TelemetryConfig = telemetryTypes.TelemetryConfig

local function isCount(value: unknown): boolean
	return type(value) == "number" and value >= 1 and value == math.floor(value)
end

--[[
	The backend publishes what a sender should know before it sends, such as
	how big a batch may be. This asks for it at the backend's `config`
	endpoint. When the backend can't be reached, or its answer doesn't hold
	both batch limits, this returns nil and the reason, and the caller keeps
	the limits it already has.
]]
local function getTelemetryConfigAsync(endpoint: string, timeoutSeconds: number): (TelemetryConfig?, string?)
	local response, failure = requestTelemetryAsync(endpoint, { method = "GET" }, timeoutSeconds)

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

	return { limits = { maxEvents = limits.maxEvents, maxBytes = limits.maxBytes } }, nil
end

return getTelemetryConfigAsync
