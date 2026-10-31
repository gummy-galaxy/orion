local getFieldValue = require("@root/canvas/query/getFieldValue")
local getRefs = require("@root/canvas/refs/getRefs")
local parseExpression = require("@root/canvas/query/parseExpression")
local queryTypes = require("@root/canvas/query/types")
local types = require("@root/types")

type Item = types.Item
type Expression = parseExpression.Expression

-- Whether a group's path of labels is the one named: a lone label names the
-- group itself, and labels separated by `/` name it from the top level down.
-- Case and the spaces around each label don't count.
local function isPathNamed(path: { string }, value: string): boolean
	local names = value:split("/")

	if #path == 0 or (#names > 1 and #names ~= #path) then
		return false
	end

	for index, name in names do
		local label = path[#path - #names + index]

		if label:lower() ~= (name:match("^%s*(.-)%s*$") :: string):lower() then
			return false
		end
	end

	return true
end

local function matchesExpression(scope: queryTypes.Scope, item: Item, expression: Expression): boolean
	local function evaluate(node: Expression): boolean?
		if node.kind == "comparison" then
			local field = node.field :: string
			local value = node.value :: string

			if field == "ref" then
				local refs = getRefs(item)

				if #refs == 0 then
					return nil
				end

				for _, ref in refs do
					if node.operator == "~" and ref.key:lower():find(value:lower(), 1, true) then
						return true
					elseif ref.key:lower() == value:lower() then
						return node.operator == "="
					end
				end

				return node.operator == "!="
			end

			if field == "group" then
				local parentId = item.parentId

				if parentId == nil then
					return nil
				end

				local path = scope.groupPaths[parentId] or {}

				if node.operator == "~" then
					return table.concat(path, " / "):lower():find(value:lower(), 1, true) ~= nil
				end

				local isNamed = parentId == value or isPathNamed(path, value)
				return if node.operator == "=" then isNamed else not isNamed
			end

			if field == "within" then
				if item.parentId == nil then
					return nil
				end

				local isNamed = false
				local seen: { [string]: boolean } = {}
				local groupId: string? = item.parentId

				-- A group nested in itself through a broken file stops the
				-- walk.
				while groupId and not seen[groupId] do
					if groupId == value or isPathNamed(scope.groupPaths[groupId] or {}, value) then
						isNamed = true
						break
					end

					seen[groupId] = true
					groupId = scope.groupParents[groupId]
				end

				return if node.operator == "=" then isNamed else not isNamed
			end

			local actual = getFieldValue(scope, item, field)
			if actual == nil then
				return nil
			end
			if node.operator == "~" then
				return actual:lower():find(value:lower(), 1, true) ~= nil
			end
			return if node.operator == "=" then actual == value else actual ~= value
		elseif node.kind == "not" then
			local result = evaluate(node.left :: Expression)
			return if result == nil then nil else not result
		elseif node.kind == "and" then
			local left = evaluate(node.left :: Expression)
			local right = evaluate(node.right :: Expression)
			if left == false or right == false then
				return false
			end
			return if left == nil or right == nil then nil else true
		else
			local left = evaluate(node.left :: Expression)
			local right = evaluate(node.right :: Expression)
			if left == true or right == true then
				return true
			end
			return if left == nil or right == nil then nil else false
		end
	end

	return evaluate(expression) == true
end

return matchesExpression
