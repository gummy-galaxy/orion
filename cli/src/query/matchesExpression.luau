local json = require("@std/json")

local graph = require("@root/graph")
local parseExpression = require("@root/query/parseExpression")
local types = require("@root/types")

type Item = types.Item
type Expression = parseExpression.Expression

local function getField(item: Item, derived: graph.Derived, field: string): string?
	local value: json.Value = nil
	if field == "kind" then
		value = if graph.isGroup(item)
			then "group"
			elseif item.type == "image" then "image"
			else item.data.itemKind or "step"
	elseif field == "status" then
		value = derived.status[item.id]
	elseif field == "recordedStatus" then
		value = item.data.status
	elseif field == "group" then
		value = item.parentId
	elseif field == "draft" then
		local github = json.asObject(item.data.github)
		value = if github then github.draft else nil
	elseif field == "ref" then
		local external = json.asObject(item.data.external)
		value = if external then external.key else nil
	else
		value = item.data[field]
	end
	if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
		return tostring(value)
	end
	return nil
end

local function matchesExpression(derived: graph.Derived, item: Item, expression: Expression): boolean
	local function evaluate(node: Expression): boolean?
		if node.kind == "comparison" then
			local field = node.field :: string
			local actual = getField(item, derived, field)
			if actual == nil then
				return nil
			end
			local value = node.value :: string
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
