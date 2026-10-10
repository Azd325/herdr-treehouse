# Security policy

Security fixes apply to the latest released version.

## Reporting a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/Azd325/herdr-treehouse/security/advisories/new).
Do not open a public issue for a suspected vulnerability. Include the version,
impact, a minimal reproduction, and redacted logs. Remove private paths,
workspace names, and credentials.

## What the plugin reads and runs

The plugin reads pane directories and workspace tokens through `herdr pane list`
and `herdr workspace list`. It runs `treehouse status --json` from pane
directories to read slot paths, states, branches, and resident-process information.
It uses `jq` to process that output, temporary files during each run, and a
keepalive timestamp in Herdr's plugin state directory.

It writes workspace tokens through `herdr workspace report-metadata` and logs
failures to stderr. It changes no Treehouse pool, workspace, tab, or pane and
starts no background process. Slot project names and branches appear in the
sidebar; redact them before sharing screenshots or logs.
