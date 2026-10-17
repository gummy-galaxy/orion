local loom = require("@repo/loom.config")

-- `lute run build` stamps the commit this binary compiles from into this file and restores it afterwards,
-- so a checkout reports "dev".
return {
	version = loom.package.version,
	commit = "dev",
}
