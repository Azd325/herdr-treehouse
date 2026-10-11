# Changelog

## 0.1.1 — 2026-10-11

- Include the tree symbol in `$th_slot`, keeping exactly one symbol in `$th_line`.
- Keep the symbol and slot name when shortening a long project name to Herdr's
  80-character token limit.

## 0.1.0 — 2026-10-10

- Add the `azd325.treehouse` plugin with slot, state, branch, and combined-line
  workspace tokens for the Herdr sidebar.
- Refresh on workspace and pane events, startup, and a manual action. Report
  changed tokens with a 30-minute time limit and renew them after 15 minutes
  on the next event.
- Read Treehouse status without changing pools, workspaces, tabs, or panes.
- Test against sanitized fixtures and fake Herdr and Treehouse commands.
