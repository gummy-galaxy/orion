local batteriesCli = require("@batteries/cli")
local types = require("@root/types")

export type Context = {
	dir: string,
	root: string,
	workspace: string,
	write: (string) -> (),
	asJson: boolean,
	runner: types.CommandRunner,
	now: () -> string,
}

export type Command = {
	read help: string,
	read define: (batteriesCli.Parser) -> (),
	read run: (batteriesCli.Parser, Context) -> (),
}

return nil
