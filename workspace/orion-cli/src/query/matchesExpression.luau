local getFieldValue = require("@root/query/getFieldValue")
local getRefs = require("@root/refs/getRefs")
local graphTypes = require("@root/graph/types")
local parseExpression = require("@root/query/parseExpression")
local types = require("@root/types")

type Item = types.Item
type Expression = parseExpression.Expression

local function matchesExpression(derived: graphTypes.Derived, item: Item, expression: Expression): boolean
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

			local actual = getFieldValue(item, derived, field)
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
