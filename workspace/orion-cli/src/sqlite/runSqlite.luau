local json = require("@std/json")

local spawnSqlite = require("@root/sqlite/spawnSqlite")

-- `sqlite3 -json` prints each statement's rows as their own array, one row per
-- line, and nothing for a statement without rows. A JSON string can't hold a
-- raw newline, so a line that starts a new array starts a new statement. Lines
-- end in "\r\n" on Windows.
local function parseRows(output: string): json.Array
	if output:match("^%s*$") then
		return {}
	end

	local joined = output:gsub("%]\r?\n%[", ",")
	return json.asArray(json.deserialize(joined) :: json.Value) or {}
end

--[[
	Runs `sql` against the database at `database` with `sqlite3 -json` and
	returns the rows of every statement that returns any, in order.
	`spawnSqlite` describes `batch` and the failures it raises.
]]
local function runSqlite(database: string, sql: string, batch: json.Value?): json.Array
	return parseRows(spawnSqlite(database, sql, "-json", batch))
end

return runSqlite
