local archivist = require("@archivist")
local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local fileNames = require("@root/fileNames")
local joinCanvasFiles = require("@root/store/joinCanvasFiles")
local openCanvasIndex = require("@root/store/openCanvasIndex")
local quoteSqlString = require("@root/sqlite/quoteSqlString")
local readSqliteValue = require("@root/sqlite/readSqliteValue")
local resolveCanvasFiles = require("@root/store/resolveCanvasFiles")
local storeTypes = require("@root/store/types")

type CanvasSnapshot = storeTypes.CanvasSnapshot

local logger = archivist.getLogger("orion.index")

-- Brings the index up to date with the folder. A file is read again when it's new, its time changed, or it changed
-- in the same second it was last read, which a time in whole seconds can't tell apart. Rows for files that are gone
-- are dropped, and `counts` records what changed for the log.
local SYNC = [[
BEGIN IMMEDIATE;
CREATE TEMP TABLE disk AS %s;
CREATE TEMP TABLE stale AS
	SELECT disk.path, disk.mtime FROM disk LEFT JOIN files ON files.path = disk.path
	WHERE files.path IS NULL OR files.mtime != disk.mtime OR disk.mtime >= files.checked;
CREATE TEMP TABLE fresh AS
	SELECT path, mtime, CAST(readfile(%s || path) AS TEXT) AS text FROM stale;
CREATE TEMP TABLE counts AS SELECT
	(SELECT count(*) FROM disk) AS total,
	(SELECT count(*) FROM stale) AS checked,
	(SELECT count(*) FROM fresh LEFT JOIN files ON files.path = fresh.path
		WHERE fresh.text IS NOT NULL AND files.text IS NOT fresh.text) AS changed,
	(SELECT count(*) FROM files WHERE path NOT IN (SELECT path FROM disk)
		OR path IN (SELECT path FROM fresh WHERE text IS NULL)) AS removed;
DELETE FROM files WHERE path NOT IN (SELECT path FROM disk) OR path IN (SELECT path FROM fresh WHERE text IS NULL);
INSERT OR REPLACE INTO files (path, folder, entry, isValid, mtime, checked, hash, text)
	SELECT
		path,
		CASE WHEN path GLOB 'nodes/*' THEN 'nodes' WHEN path GLOB 'links/*' THEN 'links' ELSE '' END,
		CASE WHEN isValid THEN
			CASE WHEN json_type(text, '$.id') = 'text' THEN json_extract(text, '$.id') END
		END,
		isValid,
		mtime,
		CAST(strftime('%%s', 'now') AS INTEGER),
		hex(sha3(text)),
		text
	FROM (
		SELECT path, mtime, text, CASE WHEN json_valid(text) THEN json_type(text) = 'object' ELSE 0 END AS isValid
		FROM fresh WHERE text IS NOT NULL
	);
COMMIT;
]]

-- Joins the index back into one canvas object, the way `joinCanvasFiles` joins the files: entries listed in the
-- canvas's order come first, in that order, then the rest by id, and only one file per id. `json()` marks each
-- array as JSON so `json_set` doesn't store it as text.
local ENTRIES = [[
json((SELECT json_group_array(json(text)) FROM (
	SELECT text FROM (
		SELECT min(files.path), files.text, files.entry, ordered.position
		FROM files LEFT JOIN (
			SELECT value AS id, min(CAST(key AS INTEGER)) AS position
			FROM json_each((SELECT text FROM files WHERE path = 'canvas.json' AND isValid), '$.order.%s')
			WHERE type = 'text' GROUP BY value
		) AS ordered ON ordered.id = files.entry
		WHERE files.folder = '%s' AND files.entry IS NOT NULL
		GROUP BY files.entry
	)
	ORDER BY position IS NULL, position, entry
)))]]

-- One JSON object, so the canvas is parsed once rather than as a string inside `sqlite3 -json`'s rows. `json()`
-- marks each value as JSON so `json_object` doesn't store it as text.
local QUERY = [[
SELECT json_object(
	'invalid', json((SELECT json_group_array(path) FROM files WHERE NOT isValid)),
	'fingerprint', (SELECT hex(sha3(group_concat(path || ':' || hash, ','))) FROM (SELECT path, hash FROM files ORDER BY path)),
	'document', json(json_set(
		json_remove((SELECT text FROM files WHERE path = 'canvas.json' AND isValid), '$.order'),
		'$.nodes', %s,
		'$.links', %s
	)),
	'localState', json((SELECT text FROM files WHERE path = 'local.json' AND isValid)),
	'files', %s,
	'total', total, 'checked', checked, 'changed', changed, 'removed', removed
) FROM counts;
]]

local function getFolderScan(dir: string, name: string): string?
	if not fs.exists(path.join(dir, name)) then
		return nil
	end

	local base = quoteSqlString(dir)
	local isFolder = name == fileNames.nodes or name == fileNames.links
	local filter = if isFolder then ` AND name GLOB '{name}/*.json' AND name NOT GLOB '{name}/*/*'` else ""

	-- 0o170000 masks the file type and 0o100000 is a regular file.
	return `SELECT name AS path, mtime FROM fsdir('{name}', {base}) WHERE (mode & 61440) = 32768{filter}`
end

local function buildScript(dir: string, includeFiles: boolean): string
	local scans: { string } = {}

	for _, name in { fileNames.document, fileNames.localState, fileNames.nodes, fileNames.links } do
		local scan = getFolderScan(dir, name)

		if scan then
			table.insert(scans, scan)
		end
	end

	local prefix = quoteSqlString(dir .. "/")
	-- A file that doesn't parse sends the read down the slower path through every file's text.
	local condition = if includeFiles then "1" else "EXISTS (SELECT 1 FROM files WHERE NOT isValid)"
	local files = `CASE WHEN {condition} THEN json((SELECT json_group_object(path, text) FROM files)) END`

	return SYNC:format(table.concat(scans, " UNION ALL "), prefix)
		.. QUERY:format(ENTRIES:format("nodes", "nodes"), ENTRIES:format("links", "links"), files)
end

local function getObject(value: json.Value?, label: string): json.Object
	local object = json.asObject(value)
	assert(object, `{label} must be a JSON object`)
	return object
end

local function query(dir: string, includeFiles: boolean): json.Object
	local database = openCanvasIndex(dir)
	local script = buildScript(dir, includeFiles)
	local succeeded, value = pcall(function()
		return readSqliteValue(database, script)
	end)

	if not succeeded then
		if type(value) ~= "table" or not (value :: any).isCorrupt then
			error(value, 0)
		end

		logger.warn("rebuilding", database, "after", (value :: any).message)
		database = openCanvasIndex(dir, true)
		value = readSqliteValue(database, script)
	end

	return getObject(value, `the index of {dir}`)
end

--[[
	Brings a canvas folder's index up to date with its files and reads the canvas from it, or nil when the folder
	has no `canvas.json`. Only files whose time changed are read again. With `includeFiles`, the snapshot also maps
	each file's path to its text, which a write compares against to rewrite only what changed. Files that don't
	parse, such as ones with git's conflict markers, are worked around by `resolveCanvasFiles`, and the snapshot
	lists the problems. Its fingerprint changes whenever any file's text does, revision or not.
]]
local function readCanvasIndex(dir: string, includeFiles: boolean): CanvasSnapshot?
	if not fs.exists(path.join(dir, fileNames.document)) then
		return nil
	end

	local row = query(dir, includeFiles)
	local invalid = json.asArray(row.invalid) or {}

	logger.debug(
		"indexed",
		dir,
		"with",
		row.changed,
		"changed and",
		row.removed,
		"removed after checking",
		row.checked,
		"of",
		row.total,
		"files"
	)

	local files: { [string]: string }? = nil

	if includeFiles or #invalid > 0 then
		local object = getObject(row.files, "the index's files")
		local texts: { [string]: string } = {}

		for file, text in object do
			if type(file) == "string" and type(text) == "string" then
				texts[file] = text
			end
		end

		files = texts
	end

	local fingerprint = if type(row.fingerprint) == "string" then row.fingerprint else nil

	-- Files that don't parse are rare, such as after a git merge that conflicted, so their canvas is joined from
	-- every file's text rather than in SQL.
	if #invalid > 0 then
		local resolved, problems = resolveCanvasFiles(files :: { [string]: string })

		for _, problem in problems do
			logger.warn(dir, problem)
		end

		return {
			document = joinCanvasFiles(resolved),
			files = if includeFiles then files else nil,
			problems = problems,
			fingerprint = fingerprint,
		}
	end

	local document = getObject(row.document, fileNames.document)

	if row.localState ~= nil and row.localState ~= json.null then
		for key, value in getObject(row.localState, fileNames.localState) do
			if type(key) == "string" then
				document[key] = value
			end
		end
	end

	return { document = document, files = files, problems = {}, fingerprint = fingerprint }
end

return readCanvasIndex
