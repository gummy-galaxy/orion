local batteriesCli = require("@batteries/cli")

export type Context = {
	dir: string,
	root: string,
	workspace: string,
	write: (string) -> (),
	asJson: boolean,
}

export type Command = {
	read help: string,
	read define: (batteriesCli.Parser) -> (),
	read run: (batteriesCli.Parser, Context) -> (),
}

return nil
