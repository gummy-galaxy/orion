local json = require("@std/json")
local net = require("@std/net")

local chooseTelemetry = require("@root/telemetry/chooseTelemetry")
local forgetTelemetryInstall = require("@root/telemetry/forgetTelemetryInstall")
local getTelemetryEndpoint = require("@root/telemetry/getTelemetryEndpoint")
local readTelemetryConsent = require("@root/telemetry/readTelemetryConsent")
local requestTelemetryAsync = require("@root/telemetry/requestTelemetryAsync")
local telemetryConstants = require("@root/telemetry/constants")

export type Outcome = "deleted" | "nothing" | "failed"

export type Options = {
	environment: { [string]: string },
	-- Specs pass this to stand in for the backend.
	requestTelemetryAsync: typeof(requestTelemetryAsync)?,
}

--[[
	Someone who shared usage data can ask for it to be deleted, from Settings
	or with `orion telemetry delete`. This asks the backend to delete every
	event sent under this machine's install id. A machine with no id has sent
	nothing, so the outcome is "nothing".

	Sharing is turned off first, and the queue of events waiting to be sent is
	deleted, so those never go out. A batch `orion server start` is already
	sending can still arrive, and it outlives the deletion. Once the backend
	accepts the request, the id is forgotten. The backend accepts it before
	the events are gone, since PostHog, where they're stored, deletes them
	later.

	Unlike sending events, a failure here is the person's to know about, so it
	comes back as "failed" with the reason. The id stays then, and sharing
	stays off, so the person can try again.
]]
local function deleteTelemetryDataAsync(root: string, options: Options): (Outcome, string?)
	local installId = readTelemetryConsent(root).installId

	if not installId then
		return "nothing", nil
	end

	chooseTelemetry(root, false, "cli", options.environment)

	local request = options.requestTelemetryAsync or requestTelemetryAsync
	local metadata: net.Metadata = {
		method = "POST",
		headers = { ["Content-Type"] = "application/json" },
		body = json.serialize(json.object({ installId = installId })),
	}
	local response, failure = request(
		getTelemetryEndpoint(options.environment, "delete"),
		metadata,
		telemetryConstants.DELETE_TIMEOUT_SECONDS
	)

	if not response then
		return "failed", `the telemetry backend couldn't be reached: {failure}`
	end

	if not response.ok then
		local didParse, body = pcall(json.deserialize, response.body)
		local reason = if didParse and type(body) == "table" then (body :: any).error else nil

		return "failed",
			if type(reason) == "string"
				then `the telemetry backend answered {response.status}: {reason}`
				else `the telemetry backend answered {response.status}`
	end

	forgetTelemetryInstall(root)

	return "deleted", nil
end

return deleteTelemetryDataAsync
