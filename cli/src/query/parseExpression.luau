export type Expression = {
	kind: string,
	field: string?,
	operator: string?,
	value: string?,
	left: Expression?,
	right: Expression?,
}

local FIELDS = {
	kind = true,
	repo = true,
	status = true,
	recordedStatus = true,
	group = true,
	draft = true,
	label = true,
	note = true,
	pr = true,
	ref = true,
	snoozed = true,
}

local function parseExpression(input: string): Expression
	local cursor = 1

	local function fail(message: string): never
		error(`query at column {cursor}: {message}`, 0)
	end

	local function skipSpace()
		while input:sub(cursor, cursor):match("%s") do
			cursor += 1
		end
	end

	local function readWord(): string?
		skipSpace()
		local word = input:sub(cursor):match("^[%a][%w]*")
		if word then
			cursor += #word
		end
		return word
	end

	local function readKeyword(keyword: string): boolean
		skipSpace()
		local ending = cursor + #keyword - 1
		if input:sub(cursor, ending):lower() ~= keyword or input:sub(ending + 1, ending + 1):match("[%w_]") then
			return false
		end
		cursor = ending + 1
		return true
	end

	local function readValue(): string
		skipSpace()
		local quote = input:sub(cursor, cursor)
		if quote ~= '"' and quote ~= "'" then
			fail("expected a quoted string value")
		end
		cursor += 1
		local parts: { string } = {}
		while cursor <= #input do
			local character = input:sub(cursor, cursor)
			if character == quote then
				cursor += 1
				return table.concat(parts)
			elseif character == "\\" then
				local nextCharacter = input:sub(cursor + 1, cursor + 1)
				if nextCharacter ~= quote and nextCharacter ~= "\\" then
					fail("only quote and backslash escapes are supported")
				end
				table.insert(parts, nextCharacter)
				cursor += 2
			else
				table.insert(parts, character)
				cursor += 1
			end
		end
		fail("unterminated quoted string")
		return ""
	end

	local parseOr: () -> Expression

	local function parsePrimary(): Expression
		skipSpace()
		if input:sub(cursor, cursor) == "(" then
			cursor += 1
			local expression = parseOr()
			skipSpace()
			if input:sub(cursor, cursor) ~= ")" then
				fail("expected ')'")
			end
			cursor += 1
			return expression
		end

		local field = readWord()
		if not field then
			fail("expected a field or '('")
		end
		if not FIELDS[field] then
			fail(`unknown field '{field}'`)
		end
		skipSpace()
		local operator = input:sub(cursor, cursor + 1)
		if operator == "!=" then
			cursor += 2
		else
			operator = input:sub(cursor, cursor)
			if operator ~= "=" and operator ~= "~" then
				fail("expected '=', '!=', or '~'")
			end
			cursor += 1
		end
		if operator == "~" and field ~= "label" and field ~= "note" and field ~= "ref" then
			fail("'~' is only supported for label, note, and ref")
		end
		local value = readValue()
		if field == "draft" and value ~= "true" and value ~= "false" then
			fail("draft must be 'true' or 'false'")
		end
		return { kind = "comparison", field = field, operator = operator, value = value }
	end

	local function parseNot(): Expression
		if readKeyword("not") then
			return { kind = "not", left = parseNot() }
		end
		return parsePrimary()
	end

	local function parseAnd(): Expression
		local expression: Expression = parseNot()
		while readKeyword("and") do
			local left = expression
			expression = { kind = "and", left = left, right = parseNot() } :: Expression
		end
		return expression
	end

	parseOr = function(): Expression
		local expression: Expression = parseAnd()
		while readKeyword("or") do
			local left = expression
			expression = { kind = "or", left = left, right = parseAnd() } :: Expression
		end
		return expression
	end

	local expression = parseOr()
	skipSpace()
	if cursor <= #input then
		fail(`unexpected '{input:sub(cursor, cursor)}'`)
	end
	return expression
end

return parseExpression
