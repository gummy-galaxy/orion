local archivist = require("@archivist")
local json = require("@std/json")
local net = require("@lute/net/server")

local applyOperations = require("@root/operations/applyOperations")
local getErrorText = require("@root/getErrorText")
local parseOperations = require("@root/operations/parseOperations")
local shared = require("@root/server/routes/shared")
local store = require("@root/store")
local types = require("@root/types")

type Doc = types.Doc
type Response = shared.Response

local logger = archivist.getLogger("orion.operations")

-- Applies slower than this are logged as warnings, so a slow write shows up in `orion serve`'s output.
local SLOW_APPLY_MS = 250

local operations = {}

-- Keeps a failure that isn't a rejection or a stale revision, with the stack where it was raised, so the log can say where.
local function captureFailure(failure: unknown): unknown
	if type(failure) == "table" then
		return failure
	end

	return { message = getErrorText(failure), traceback = debug.traceback("", 2) }
end

-- Applies a list of edits as one change, under the store lock. If any edit no longer applies, the whole list is
-- refused with the position of the edit that failed, and the file is left alone. `baseRevision`, when sent, must
-- still be the saved revision.
function operations.handle(request: net.ReceivedRequest, root: string, active: string): Response
	if request.method ~= "POST" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local tagged = request.headers["x-orion-canvas"]
	if tagged and tagged ~= active then
		return shared.reply(409, json.object({ error = "canvas changed" }))
	end

	local parsed, change = pcall(function()
		local body = shared.parseBody(request)
		local baseValue = body.baseRevision
		assert(
			baseValue == nil or baseValue == json.null or type(baseValue) == "number",
			"baseRevision must be a number or null"
		)
		local values = assert(json.asArray(body.operations), "operations must be an array")
		assert(#values > 0, "operations needs at least one edit")
		return {
			baseRevision = if type(baseValue) == "number" then baseValue else nil,
			operations = parseOperations(values),
		}
	end)

	if not parsed then
		return shared.reply(400, json.object({ error = getErrorText(change) }))
	end

	local dir = store.getWorkspaceDir(root, active)
	local started = os.clock()
	local succeeded, result = xpcall(store.transaction, captureFailure, dir, function(doc: Doc)
		if change.baseRevision ~= nil and change.baseRevision ~= doc.revision then
			error({ stale = true, revision = doc.revision }, 0)
		end

		applyOperations(doc, change.operations)
	end)
	local elapsed = math.floor((os.clock() - started) * 1000)

	if succeeded then
		local doc = result :: Doc

		if elapsed >= SLOW_APPLY_MS then
			logger.warn("applied", #change.operations, "operations to", active, "in", elapsed, "ms")
		else
			logger.debug("applied", #change.operations, "operations to", active, "in", elapsed, "ms")
		end

		return shared.reply(200, json.object({ revision = doc.revision, applied = #change.operations }))
	end

	local failure: any = result

	if type(failure) == "table" and failure.stale then
		return shared.reply(409, json.object({ error = "revision changed", revision = failure.revision }))
	end

	if type(failure) == "table" and failure.rejected then
		return shared.reply(409, json.object({ error = failure.message, index = failure.index, op = failure.op }))
	end

	local message = if type(failure) == "table" and failure.message then failure.message else getErrorText(failure)
	local trace = if type(failure) == "table" then failure.traceback else nil

	logger.err("could not apply", #change.operations, "operations to", active, "after", elapsed, "ms:", message)

	if trace then
		logger.err(trace)
	end

	return shared.reply(500, json.object({ error = message }))
end

return table.freeze(operations)
