local applyOperation = require("@root/canvas/operations/applyOperation")
local getErrorCode = require("@root/common/errors/getErrorCode")
local getErrorText = require("@root/common/errors/getErrorText")
local json = require("@std/json")
local operationTypes = require("@root/canvas/operations/types")
local restoreDoc = require("@root/canvas/operations/restoreDoc")
local types = require("@root/types")

type Doc = types.Doc
type Operation = operationTypes.Operation
type Restore = operationTypes.Restore

-- Raised when an operation no longer applies. The whole list is refused, and
-- `index` names the operation that failed.
export type Rejection = {
	rejected: true,
	index: number,
	op: string,
	code: types.ErrorCode?,
	message: string,
}

-- Applies a list in order, as one change. If any operation fails, the ones
-- before it are undone and the list is refused. Returns each operation's
-- inverse, and each one's answer or json.null, in the same order as the list.
local function applyOperations(doc: Doc, operations: { Operation }): ({ Restore }, json.Array)
	local restores: { Restore } = {}
	local answers: json.Array = {}

	for index, operation in operations do
		local succeeded, result, answer = pcall(applyOperation, doc, operation)

		if not succeeded then
			for undo = #restores, 1, -1 do
				restoreDoc(doc, restores[undo])
			end

			local rejection: Rejection = {
				rejected = true,
				index = index,
				op = operation.op,
				code = getErrorCode(result),
				message = getErrorText(result),
			}
			error(rejection, 0)
		end

		table.insert(restores, result :: Restore)
		table.insert(answers, if answer == nil then json.null else answer)
	end

	return restores, answers
end

return applyOperations
