local applyOperation = require("@root/operations/applyOperation")
local getErrorText = require("@root/getErrorText")
local operationTypes = require("@root/operations/types")
local restoreDoc = require("@root/operations/restoreDoc")
local types = require("@root/types")

type Doc = types.Doc
type Operation = operationTypes.Operation
type Restore = operationTypes.Restore

-- Raised when an operation no longer applies. The whole list is refused, and `index` names the operation that failed.
export type Rejection = { rejected: true, index: number, op: string, message: string }

-- Applies a list in order, as one change. If any operation fails, the ones before it are undone and the list is
-- refused. Returns each operation's inverse, in the same order as the list.
local function applyOperations(doc: Doc, operations: { Operation }): { Restore }
	local restores: { Restore } = {}

	for index, operation in operations do
		local succeeded, result = pcall(applyOperation, doc, operation)

		if not succeeded then
			for undo = #restores, 1, -1 do
				restoreDoc(doc, restores[undo])
			end

			local rejection: Rejection = {
				rejected = true,
				index = index,
				op = operation.op,
				message = getErrorText(result),
			}
			error(rejection, 0)
		end

		table.insert(restores, result :: Restore)
	end

	return restores
end

return applyOperations
