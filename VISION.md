# Vision

A Herdr plugin that makes Treehouse worktrees easy to see in the Herdr sidebar.

This file holds the decisions of 2026-10-10.
A rule under "Proposals" is not decided.

## Decided

### Who it is for

- The plugin is general. It works for each Treehouse user.
- It works without Firstmate. It works the same for a Firstmate worker.

### Scope of the first version

- The sidebar line only. This is the minimum.
- More scope is possible in a later release.

### Content of the line

- Slot, state, branch. Example: `🌳 research#1 · in-use · fm/fix-x`.
- The slot value starts with the tree symbol (`🌳 research#1`); the full line holds the symbol one time. For a narrow sidebar the layout has three rows: workspace, then slot and state, then the Herdr branch row.
- The content is configurable. The plugin reports one token for each value and one token for the full line. The user selects and orders the tokens in the Herdr `config.toml`.

### Refresh

- Events only: workspace focused, workspace created, pane created, pane exited, startup, and a manual action.
- No background process and no timer.
- Each token has a time limit.
- The plugin reports a token only when its value changed.
- A background refresh is open for a later release.

### Safety

- Read-only on the Treehouse side. The plugin reads `treehouse status --json` and the documented `herdr pane list` and `herdr workspace list` output. It runs no command that changes a pool.
- The plugin does not rename or reorder a workspace or a tab.
- The plugin puts no `treehouse` command on `PATH`.
- A workspace that is not in a slot gets no token. The plugin clears a stale token.
- The plugin fails quiet. When `treehouse` or `jq` is missing, or the JSON has an unknown form, it exits with status 0, reports nothing, and writes one line to the plugin log.

### Repository

- Name: `herdr-treehouse`. Plugin id: `azd325.treehouse`.
- Owner: the GitHub account `Azd325`.
- The repository is local until publication. The plugin is used for some days first; the publication is a decision of the owner.
- After publication, the checks workflow must pass on Linux and macOS, and one install from the public repository must pass in a clean, separate Herdr session.
- The marketplace topic `herdr-plugin` is a separate last step, on the owner's word.
- Licence: MIT.
- A checks workflow exists since the public-release preparation of 2026-10-10.

### Not in the first version

- A pool board.
- An action that changes a slot.
- Nesting of slots under their repository.
- A background refresh.
- Tokens for the lease holder and for the pool count.
- A change to Treehouse or to Firstmate.

## Proposals

These rules are not decided. Each one needs a decision before work starts.

- **Background refresh.** A process that reports at an interval, for values that are never stale. Marked as open for a later release.
- **More tokens.** The lease holder on a leased slot. The count of free slots on the workspace of the repository.
- **Push from Treehouse.** A refresh from Treehouse `post_get` and `post_return` hooks, when Treehouse has them (`kunchenguid/treehouse#158`).
- **Pool board and guarded actions.** A popup with the slots of the open repositories, and actions such as "open slot as workspace". An action that returns a slot must refuse a slot with resident processes or with a lease that the plugin did not make.
- **Rule for all later scope.** The plugin stays in its own repository and asks for no multiplexer logic in Treehouse.
