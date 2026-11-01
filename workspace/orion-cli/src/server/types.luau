-- What `orion server start` times for usage telemetry. `derive` is a pass
-- that works out a canvas's status for the app, timed when the server sends
-- the result. `server_flush` is a batch of the app's edits that the server
-- applied and wrote without an error.
export type Metric = "derive" | "server_flush"

-- Collects those timings until the server queues them as usage events.
-- `createPerformanceSummaries` makes one, and the server passes it to the code
-- that derives canvases and applies edits.
export type Timings = {
	record: (metric: Metric, durationMs: number) -> (),
	-- The size of the canvas last derived: its work items, which leave out
	-- components and deferred cards, and its groups.
	setCanvasSize: (cardCount: number, groupCount: number) -> (),
}

return nil
