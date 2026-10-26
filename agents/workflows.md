# Workflows

- Keep each `run:` step to one command, ideally `lute run <script>`. Multi-line shell and multi-step logic go in a Luau script in `.lute/`, run from the repository root, so it runs locally the same way. Prefer `@std/*`, and use `process.run` from `@std/process` when an argument may contain spaces. Name steps in Title Case.
- Run a script's body through `runScript` from `workspace/orion-cli/src/runScript.luau`. Lute exits 0 for some uncaught errors, such as a `process.run` whose program is missing, so without it a failed step can pass.
- Reference actions from the `actions` organization by major tag, such as `actions/checkout@v7`. Pin every other action to a commit SHA with a version comment.
- Set `timeout-minutes` to about one and a half times a measured run. Raise it only when real runs get close.
- Write every job as a future required check, since most become required once the repository is public. Skip work with a job condition fed by a filter job, like `ci-loading` in `ci.yml`, rather than workflow-level `paths`, which leaves a required check waiting forever. Give each job a `name:` that says what it checks and no other workflow uses, such as `Docs Deploy` rather than `deploy`, because a required check matches that name alone. Filter jobs are required too: when one fails, the jobs behind it are skipped, and a skipped job passes its check.
