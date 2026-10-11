# Releasing

Releases are SemVer-tagged GitHub source releases, with no binary assets.
Publication is a separate maintainer decision; this checklist does not authorize it.

`herdr plugin install owner/repo` takes the head of the default branch.
Each push to `main` reaches users at once, so `main` must always be in a released condition.
A fixed version needs `--ref <tag>`.

## One-time setup for a new repository

- [ ] Create the repository empty and public: no README, no licence, and no `.gitignore` from GitHub.
- [ ] Enable GitHub immutable releases, before the first release.
- [ ] Enable GitHub private vulnerability reporting, before the first push, so the route in [SECURITY.md](SECURITY.md) works from the start.
- [ ] Push `main` only. Never use `--all`, `--mirror`, or `--tags`.

## Each release

- [ ] Start from a clean `main` checkout and run the checks in
      [CONTRIBUTING.md](CONTRIBUTING.md).
- [ ] Review tracked files and commit messages for private paths, names,
      hosts, credentials, and captured session data.
- [ ] Set the version in `herdr-plugin.toml`, and set the version and the
      release date in [CHANGELOG.md](CHANGELOG.md).
      Commit and validate the release preparation.
- [ ] Confirm that the Linux and macOS GitHub checks passed for that commit,
      and record which live environments were actually tested.
- [ ] Install from the public repository with `herdr plugin install owner/repo`.
      If a local checkout is linked, run `herdr plugin unlink` first.
      Check the preview and the tokens in the sidebar.
- [ ] Create a signed tag on the checked commit, using the manifest version:

  ```sh
  git tag -s v0.1.1 -m 'herdr-treehouse 0.1.1'
  git verify-tag v0.1.1
  ```

- [ ] Push the tag. Create a draft GitHub source release for that tag, with
      changelog notes and no attached binaries. Read it, then publish it.
- [ ] Verify the source archive against the tagged tree.
- [ ] Install the fixed version with `herdr plugin install owner/repo --ref <tag>`.

## Marketplace listing

Add the `herdr-plugin` repository topic as the last step, and only on the maintainer's word.
Herdr users then find the plugin in the marketplace.

## Recovery

A published version or tag is never replaced, moved, or re-created. A fault gets a new version. Immutable releases must be enabled for this repository before the first release (see the one-time setup): GitHub then blocks moving or deleting a published tag and changing or deleting its release assets, while the release title and notes stay editable.

The maintainer decides how to recover from a broken release. Choose one:

- Point users to the previous working version in the release notes.
- Publish a corrective patch release: set the next version in `herdr-plugin.toml`, update [CHANGELOG.md](CHANGELOG.md), and repeat the steps above.

Withdrawal does not apply, because this project publishes no package to a registry.

Verify the chosen recovery: run the checks in [CONTRIBUTING.md](CONTRIBUTING.md) on the new commit, verify the new tag with `git verify-tag`, and verify the source archives of the new release. Publishing the tag, the release, or the release notes needs the maintainer's approval. Link the decision from the release notes.
