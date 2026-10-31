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

	-- `orion server start` sends what's queued this often. The backend allows
	-- 30 batches a minute from each install, far more than this uses.
	SEND_SECONDS = 60,

	-- A request to the backend that takes longer than this is given up on.
	-- That's long enough for a slow network, and short enough that a backend
	-- that can't be reached doesn't hold up the next send.
	TIMEOUT_SECONDS = 5,

	-- Lute's requests have no timeout of their own, so Orion checks whether a
	-- request has finished this often while it waits.
	POLL_SECONDS = 0.1,

	-- The CLI and agents add events to the queue file, and only `orion server
	-- start` sends them and empties it. On a machine where the server never
	-- runs, the file would keep growing, so it stops at this size and later
	-- events are dropped. That's room for several days of normal use.
	MAX_QUEUE_BYTES = 256 * 1024,

	-- The backend publishes how many events and bytes one batch may hold.
	-- Until it answers, Orion uses the limits it had when this build shipped.
	DEFAULT_LIMITS = { maxEvents = 100, maxBytes = 64 * 1024 },

	-- Each batch carries the install id and build alongside its events. This
	-- much of the backend's byte limit is kept for them, so the events alone
	-- stay under it.
	ENVELOPE_BYTES = 4 * 1024,

	-- The app hands its events to `orion server start` in one request, which
	-- may hold at most this many events and bytes. The server splits what it
	-- queues by the backend's limits later, so these needn't match them.
	MAX_APP_EVENTS = 100,
	MAX_APP_BODY_BYTES = 64 * 1024,
})
