local json = require("@std/json")

local spawnSqlite = require("@root/storage/index/spawnSqlite")

--[[
	Runs `sql` against the database at `database` and parses the one JSON value
	its last statement returns, or nil when it returns none. `sqlite3 -json`
	prints a JSON value as a string, which would be parsed twice, so this prints
	it as it is. `spawnSqlite` describes `batch` and the failures it raises.
]]
local function readSqliteValue(database: string, sql: string, batch: json.Value?): json.Value?
	local output = spawnSqlite(database, sql, "-list", batch)

	if output:match("^%s*$") then
		return nil
	end

	return json.deserialize(output)
end

return readSqliteValue
