# herdr-treehouse

[![CI status](https://img.shields.io/github/actions/workflow/status/Azd325/herdr-treehouse/ci.yml?branch=main)](https://github.com/Azd325/herdr-treehouse/actions/workflows/ci.yml) [![Latest release](https://img.shields.io/github/v/release/Azd325/herdr-treehouse)](https://github.com/Azd325/herdr-treehouse/releases) [![Licence: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A [Herdr](https://herdr.dev) plugin for [Treehouse](https://github.com/kunchenguid/treehouse) worktrees.
It shows the Treehouse slot of each workspace on its row in the sidebar:

```
🌳 research#1 · in-use · fm/fix-x
```

The plugin is read-only.
It needs no other integration tool and no change to Treehouse.

## Requirements

- Herdr 0.7.5 or newer, on macOS or Linux
- `treehouse` and `jq` (1.6 or newer) on the `PATH` of the Herdr server
- A POSIX `sh`

The plugin was seen working in a real Herdr 0.9.3 sidebar on macOS with
Treehouse 3.1.2 and slots in the `in-use` state. The tests use output from
those versions. Other states were exercised only in fixture tests. CI runs the fixture
tests on Linux and macOS runners. No live Linux sidebar was tested.

## Install

Install the plugin from GitHub with:

```sh
herdr plugin install Azd325/herdr-treehouse
```

For a local checkout instead:

```sh
herdr plugin link /path/to/herdr-treehouse
herdr plugin list
```

## Configure the sidebar

A plugin cannot put a row in the sidebar and cannot set a colour.
It reports values only.
You select the tokens, their order and their style in the Herdr `config.toml`.
Without these lines the sidebar shows nothing from this plugin.

The three-row layout shows the workspace, then the slot and state, then
Herdr's own branch row. It also suits a narrow sidebar:

```toml
[ui.sidebar.spaces]
rows = [
  ["state_icon", "workspace"],
  ["$th_slot", "$th_state"],
  ["branch", "git_status"],
]
```

The default line, in its own row:

```toml
[ui.sidebar.spaces]
rows = [
  ["state_icon", "workspace"],
  ["branch", "git_status"],
  ["$th_line"],
]
```

Your own selection and order, with a colour for each state.
The `rules` key needs Herdr 0.9.0 or newer:

```toml
[ui.sidebar.spaces]
rows = [
  ["state_icon", "workspace"],
  ["branch", "git_status"],
  [
    "$th_slot",
    { token = "$th_state", rules = [
      { equals = "available", fg = "#98c379" },
      { equals = "dirty", fg = "#e5c07b" },
      { equals = "leased", fg = "#c678dd" },
      { equals = "in-use", fg = "#e06c75" },
    ] },
    { token = "$th_branch", dim = true },
  ],
]
```

Herdr has no rule yet that hides one value when another value is present, so the example above shows the branch twice; see the [Herdr discussion](https://github.com/herdrdev/herdr/discussions/5167).

Herdr puts ` · ` between the values of a row.
A row without a value does not show, so a workspace outside a slot gets no empty line.

Apply the change:

```sh
herdr server reload-config
```

To refresh from a key, bind the action. Select a key that is free in your configuration:

```toml
[[keys.command]]
key = "prefix+t"
type = "plugin_action"
command = "azd325.treehouse.refresh"
description = "Treehouse: refresh"
```

The same action from a shell:

```sh
herdr plugin action invoke azd325.treehouse.refresh
```

## Tokens

All token names start with `th_`.

| Token | Value | Example |
| --- | --- | --- |
| `$th_line` | Slot, state and branch in one value | `🌳 research#1 · in-use · fm/fix-x` |
| `$th_slot` | Tree symbol, project and slot name | `🌳 research#1` |
| `$th_state` | State of the slot | `in-use` |
| `$th_branch` | Branch of the slot, or `detached` | `fm/fix-x` |

- The project is the last part of the slot path.
- The state is the `status` value of `treehouse status --json`: `available`, `dirty`, `in-use`, `leased`, `damaged` or `unverified`.
- A slot without a branch that is not detached (a Jujutsu slot, a damaged slot) has no `$th_branch`.
- A workspace is in a slot when the directory of one of its panes is in the slot.
  The directory is `foreground_cwd`, or `cwd` when Herdr reports no `foreground_cwd`.
  The first such pane in the order of `herdr pane list` gives the tokens.
- A workspace that is not in a slot has no token. The plugin clears the tokens when a workspace leaves a slot.
- Herdr keeps 80 characters of a value; the tree symbol counts as one character. The plugin cuts a longer `$th_line` and ends it with `…`.
  For `$th_slot`, it cuts a long project name so that the symbol and slot name stay.

Treehouse reports `you're here` for the slot that contains the directory of the caller.
The caller is the plugin, so this value says nothing about your pane.
The plugin reports `in-use` when that slot has resident processes.
When that slot has no resident process, `$th_state` is `you're here`.

## Limits

- **Values can be stale between events.** Treehouse changes outside Herdr start no event.
  A slot that another terminal returns keeps its old value until the next event or the manual action.
- **Each token has a time limit of 30 minutes.** Herdr removes a token that no run reported in that time, so a wrong value does not stay.
  A run reports a token only when its value changed. After 15 minutes, the next run reports all tokens again, which starts a new time limit.
  In a session without an event for 30 minutes, the row disappears until the next event.
- **The compact sidebar and the mobile sidebar show no tokens.** Herdr applies row layouts only to the expanded desktop sidebar.
- **Herdr drops all tokens when its server restarts.** The startup hook reports them again.
- Each run calls `treehouse status --json` one time for each pool that has an open workspace.

### How it works

```
Herdr event                bin/refresh.sh
(workspace focused,        1. herdr pane list            directory of each pane
 workspace created,  --->  2. treehouse status --json    slots of the pool of that directory
 pane created,             3. herdr workspace list       tokens that each workspace has now
 pane exited,              4. herdr workspace report-metadata
 startup,                     only for a workspace with a changed value
 manual action)                          |
                                         v
                           Space row in the sidebar,
                           as your config.toml sets it
```

Each run is short and then exits.
There is no background process and no timer.

### What the plugin does not do

- It runs no Treehouse command other than `treehouse status --json`.
- It does not rename, move or close a workspace, a tab or a pane.
- It puts no command on your `PATH`.

## Troubleshooting

The plugin exits with status 0 and reports nothing when `treehouse` or `jq` is missing, or when the output of a command has an unknown form.
It writes one line to the plugin log:

```sh
herdr plugin log list --plugin azd325.treehouse
```

## Uninstall

```sh
herdr plugin uninstall azd325.treehouse
```

For a local checkout that you linked with `herdr plugin link`, use
`herdr plugin unlink azd325.treehouse` instead.

Then remove the `$th_` tokens from `ui.sidebar.spaces.rows`.

## Tests

```sh
sh test/run.sh
TEST_SHELL=dash dash test/run.sh
```

The tests run `bin/refresh.sh` with the fake `herdr` and `treehouse` commands of `test/bin` on a test `PATH`.
The fixtures in `test/fixtures` have the form of recorded `herdr pane list`, `herdr workspace list` and `treehouse status --json` output, with placeholder paths.

Lint:

```sh
shellcheck bin/refresh.sh test/run.sh test/bin/herdr test/bin/treehouse
```

## License

MIT. See [LICENSE](LICENSE).
