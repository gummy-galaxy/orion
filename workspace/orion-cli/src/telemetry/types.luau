-- Whether someone on this machine chose to share usage data. "undecided" means
-- nobody has answered yet, which the app asks about once on launch.
export type Choice = "undecided" | "on" | "off"

-- What `telemetry.json` holds. Only a machine that opted in has an install id.
export type Consent = {
	choice: Choice,
	installId: string?,
}

export type Status = {
	choice: Choice,
	installId: string?,
	-- The environment variable that turns telemetry off whatever the choice,
	-- such as `DO_NOT_TRACK`.
	override: string?,
	-- Whether events may be sent: opted in, with no override.
	enabled: boolean,
}

-- A property's value. Events carry counts, durations, flags, and Orion's own
-- names, never anything nested.
export type PropertyValue = string | number | boolean

-- One event waiting in the queue, in the shape the backend takes. A session id
-- ties app events to the launch they came from; CLI and MCP events have none.
export type QueuedEvent = {
	name: string,
	sessionId: string?,
	timestamp: string,
	properties: { [string]: PropertyValue },
}

-- How big a batch the backend takes, which it publishes at its `config`
-- endpoint.
export type Limits = {
	maxEvents: number,
	maxBytes: number,
}

-- What the backend tells a sender before it sends, from its `config` endpoint.
export type TelemetryConfig = {
	limits: Limits,
}

return nil
