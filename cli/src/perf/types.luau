local json = require("@std/json")

-- Where a perf run happened, recorded on every event it sends.
export type RunContext = {
	eventName: string,
	pullRequest: number?,
	runner: string?,
	runUrl: string?,
}

export type PerfEvent = {
	event: string,
	properties: json.Object,
}

return table.freeze({})
