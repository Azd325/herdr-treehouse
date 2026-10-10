# Contributing

## Checks

Requirements: POSIX `sh`, `dash`, `jq` 1.6 or newer, and `shellcheck`.
Run from the repository root:

```sh
sh test/run.sh
TEST_SHELL=dash dash test/run.sh
shellcheck bin/refresh.sh test/run.sh test/bin/herdr test/bin/treehouse
```

The GitHub checks workflow runs these checks on Linux and macOS, with dash
also installed as `sh` for the second test run.

## Workflow

Make a focused change on a branch, run the checks, and include documentation
when behavior changes. Use placeholder paths and names in fixtures and reports.

- Keep Treehouse read-only: the plugin may run only `treehouse status --json`.
- Tests must use the fakes in `test/bin`. Never run a Herdr command against a
  running session in tests.
- Proposals in [VISION.md](VISION.md) need a decision before implementation.

Maintainers should follow [RELEASING.md](RELEASING.md).
Report vulnerabilities privately; see [SECURITY.md](SECURITY.md).
