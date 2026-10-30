local archivist = require("@archivist")
local fs = require("@std/fs")
local json = require("@std/json")
local task = require("@std/task")
local time = require("@std/time")

local adapterTypes = require("@root/adapters/types")
local collectSessionsAsync = require("@root/ingest/collectSessionsAsync")
local getAdapter = require("@root/adapters/getAdapter")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local ingestTypes = require("@root/ingest/types")
local loadDoc = require("@root/store/loadDoc")
local placeRecords = require("@root/ingest/placeRecords")
local runCommand = require("@root/command")
local runTransaction = require("@root/store/runTransaction")
local types = require("@root/types")

type AgentVerbs = adapterTypes.AgentVerbs
type Result = ingestTypes.Result
type SessionCache = ingestTypes.SessionCache
type Doc = types.Doc
type Source = types.Source
type Runner = types.CommandRunner
type Watch = typeof(fs.watch(""))

-- How often the loop drains its watches.
local CHECK_SECONDS = 0.5
-- Lists sessions again this often even when no watched folder changed, which
-- catches a transcript that moved while its process stayed busy.
local REFRESH_SECONDS = 60
local logger = archivist.getLogger("orion.sessions")
local sessions = {}

local function isSameValue(a: unknown, b: unknown): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end

	for key, value in a :: { [unknown]: unknown } do
		if not isSameValue(value, (b :: { [unknown]: unknown })[key]) then
			return false
		end
	end

	for key in b :: { [unknown]: unknown } do
		if (a :: { [unknown]: unknown })[key] == nil then
			return false
		end
	end

	return true
end

-- Each card's session refs by card and ref id, without when they were
-- checked, so a pass that found nothing new can skip the write.
local function getSessionFacts(doc: Doc): { [string]: json.Object }
	local facts: { [string]: json.Object } = {}

	for _, item in doc.nodes do
		for index, value in json.asArray(item.data.refs) or {} do
			local ref = json.asObject(value)

			if ref and ref.kind == "session" then
				local copy = table.clone(ref)
				copy.checkedAt = nil
				facts[`{item.id}:{ref.id or index}`] = copy
			end
		end
	end

	return facts
end

local function copyDoc(doc: Doc): Doc
	local copy = table.clone(doc)
	copy.nodes = {}

	for _, item in doc.nodes do
		local node = table.clone(item)
		node.data = json.deserialize(json.serialize(item.data)) :: json.Object
		table.insert(copy.nodes, node)
	end

	return copy
end

-- The canvas's sources whose adapters have agent verbs.
local function getAgentSources(doc: Doc): { { source: Source, agent: AgentVerbs } }
	local found: { { source: Source, agent: AgentVerbs } } = {}

	for _, source in doc.settings.sources do
		local succeeded, adapter = pcall(getAdapter, source.kind)

		if succeeded and adapter.agent then
			table.insert(found, { source = source, agent = adapter.agent })
		end
	end

	return found
end

--[[
	Keeps the active canvas's session refs current. It watches each agent
	source's folders, such as Claude Code's `sessions/`, and lists sessions
	again soon after one changes, and every minute regardless. Each source's
	cache lives as long as the loop, so an adapter rereads only what changed.
	It writes the canvas only when a session ref's facts did, and never adds a
	card.
]]
function sessions.create(root: string, active: () -> string, runner: Runner?)
	local command = runner or runCommand
	local caches: { [string]: SessionCache } = {}
	local watches: { Watch } = {}
	local watchedKey = ""
	local watchedCanvas = ""
	local lastRefresh = 0
	local isRunning = false
	local isClosed = false
	local loop = {}

	local function closeWatches()
		for _, watch in watches do
			watch:close()
		end

		watches = {}
	end

	-- Watches the folders the canvas's agent sources name, starting over when
	-- the canvas or its sources change.
	local function updateWatches(canvas: string, agentSources: { { source: Source, agent: AgentVerbs } })
		local paths: { string } = {}

		for _, entry in agentSources do
			local getPaths = entry.agent.watchPaths

			for _, watchPath in if getPaths then getPaths(entry.source) else {} do
				table.insert(paths, watchPath)
			end
		end

		local key = table.concat(paths, "\n")

		if key == watchedKey and canvas == watchedCanvas then
			return
		end

		closeWatches()

		if canvas ~= watchedCanvas then
			caches = {}
		end

		watchedKey, watchedCanvas = key, canvas

		for _, watchPath in paths do
			local succeeded, watch = pcall(fs.watch, watchPath)

			if succeeded then
				table.insert(watches, watch)
			end
		end
	end

	-- Lists each agent source's sessions against a snapshot, then takes the
	-- canvas lock only when placing them changes a session ref. Returns
	-- whether it wrote.
	function loop.refreshAsync(): boolean
		if isRunning then
			return false
		end

		isRunning = true
		local startedAt = time.now()
		local canvas = active()
		local didWrite = false

		local succeeded, failure = pcall(function()
			local dir = getWorkspaceDir(root, canvas)
			local snapshot = loadDoc(dir)
			local agentSources = getAgentSources(snapshot)
			local now = os.date("!%Y-%m-%dT%H:%M:%SZ") :: string
			local context = { now = now, since = now, doc = snapshot, commands = {} }
			local results: { Result } = {}

			updateWatches(canvas, agentSources)

			for _, entry in agentSources do
				local source = entry.source
				local cache = caches[source.id] or { repos = {}, agent = {} }
				caches[source.id] = cache
				table.insert(results, {
					source = source,
					report = { id = source.id, added = 0, updated = 0, linked = 0 },
					records = collectSessionsAsync(source, entry.agent, command, context, cache),
				})
			end

			if #results == 0 then
				return
			end

			local preview = copyDoc(snapshot)
			placeRecords(preview, results)

			if isSameValue(getSessionFacts(preview), getSessionFacts(snapshot)) then
				return
			end

			runTransaction(dir, function(doc)
				placeRecords(doc, results)
			end)
			didWrite = true
		end)

		lastRefresh = os.time()
		isRunning = false
		local elapsed = math.floor(time.since(startedAt) * 1000)

		if succeeded then
			logger.debug("session refresh of", canvas, "took", elapsed, "ms, wrote", didWrite)
		else
			logger.warn("session refresh of", canvas, "failed after", elapsed, "ms:", failure)
		end

		return didWrite
	end

	function loop.start()
		task.spawn(function()
			loop.refreshAsync()

			while not isClosed do
				local hasChanged = false

				for _, watch in watches do
					while watch:next() do
						hasChanged = true
					end
				end

				if hasChanged or os.time() - lastRefresh >= REFRESH_SECONDS or active() ~= watchedCanvas then
					loop.refreshAsync()
				end

				task.wait(CHECK_SECONDS)
			end
		end)
	end

	function loop.close()
		isClosed = true
		closeWatches()
	end

	return loop
end

return table.freeze(sessions)
