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

return nil
