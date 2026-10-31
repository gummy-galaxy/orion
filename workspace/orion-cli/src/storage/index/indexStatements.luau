-- SQL shared by the statements that keep a canvas index's `files` table
-- current.
return table.freeze({
	-- Records each row of the temporary `fresh` table, a file's path, time in
	-- whole seconds, and text, as the index's view of that file, marking when
	-- it was checked so a change later in the same second is caught.
	upsertFresh = [[
INSERT OR REPLACE INTO files (path, folder, entry, isValid, mtime, checked, hash, text)
	SELECT
		path,
		CASE WHEN path GLOB 'nodes/*' THEN 'nodes' WHEN path GLOB 'links/*' THEN 'links'
			WHEN path GLOB 'placements/*' THEN 'placements' ELSE '' END,
		CASE WHEN isValid THEN
			CASE WHEN json_type(text, '$.id') = 'text' THEN json_extract(text, '$.id') END
		END,
		isValid,
		mtime,
		CAST(strftime('%s', 'now') AS INTEGER),
		hex(sha3(text)),
		text
	FROM (
		SELECT path, mtime, text, CASE WHEN json_valid(text) THEN json_type(text) = 'object' ELSE 0 END AS isValid
		FROM fresh WHERE text IS NOT NULL
	);
]],
})
