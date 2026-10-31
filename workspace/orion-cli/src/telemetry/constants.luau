--[[
	The numbers and addresses that shape how usage data is queued and sent,
	kept in one place so they're easy to find and change together.
]]
return table.freeze({
	-- The backend lives at this address. Its endpoints sit under it, such as
	-- `/events` for sending batches and `/config` for its limits. Setting
	-- `ORION_TELEMETRY_URL` points Orion at another backend, such as one
	-- running locally for testing.
	BASE_URL = "https://api.oriongraph.app/telemetry/v1",

	-- `orion server start` sends what's queued this often. A minute of normal
	-- use fits in one batch, and the backend accepts up to 30 batches a minute
	-- from each install.
	SEND_SECONDS = 60,

	-- A request to the backend that takes longer than this is given up on.
	-- That's long enough for a slow network, and short enough that a backend
	-- that can't be reached doesn't hold up the next send.
	TIMEOUT_SECONDS = 5,

	-- Requests in Lute, the runtime Orion's CLI runs on, can't set a timeout.
	-- So while a request runs, Orion checks this often whether it's done, and
	-- stops waiting after the timeout above.
	POLL_SECONDS = 0.1,

	-- The CLI and agents add events to the queue file, and only `orion server
	-- start` sends them and empties it. On a machine where the server never
	-- runs, the file would keep growing. So it stops at this size, and events
	-- that don't fit are dropped.
	MAX_QUEUE_BYTES = 256 * 1024,

	-- The backend publishes how many events and bytes one batch may hold.
	-- These are the limits it had when this build shipped. Orion uses them
	-- until the backend tells it otherwise.
	DEFAULT_LIMITS = { maxEvents = 100, maxBytes = 64 * 1024 },

	-- Each batch carries the install id and build alongside its events. This
	-- much of the backend's byte limit is kept for them, so the events alone
	-- stay under it.
	ENVELOPE_BYTES = 4 * 1024,

	-- The app hands its events to `orion server start` in a request that may
	-- hold at most this many events and this many bytes. When the server sends
	-- them on, it splits them by the backend's limits, so these two needn't
	-- match those.
	MAX_APP_EVENTS = 100,
	MAX_APP_BODY_BYTES = 64 * 1024,
})
