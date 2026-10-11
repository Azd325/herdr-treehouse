# Releasing

Releases are SemVer-tagged GitHub source releases, with no binary assets.
Publication is a separate maintainer decision; this checklist does not authorize it.

- [ ] Start from a clean `main` checkout and run the checks in
      [CONTRIBUTING.md](CONTRIBUTING.md). Confirm the Linux and macOS GitHub
      checks passed, and record which live environments were actually tested.
- [ ] Review tracked files and commit messages for private paths, names,
      hosts, credentials, and captured session data.
- [ ] Set the version in `herdr-plugin.toml` and update [CHANGELOG.md](CHANGELOG.md).
      Commit and validate the release preparation.
- [ ] Create a signed tag on the checked commit, using the manifest version:

  ```sh
  git tag -s v0.1.1 -m 'herdr-treehouse 0.1.1'
  git verify-tag v0.1.1
  ```

- [ ] Publish the tag and create a GitHub source release for that tag, with
      changelog notes and no attached binaries. Verify the source archives.
- [ ] Enable GitHub private vulnerability reporting and add the `herdr-plugin`
      repository topic so Herdr users can discover the plugin.

## Recovery

A published version or tag is never replaced, moved, or re-created. A fault gets a new version. Enable GitHub immutable releases for this repository before the first release: GitHub then blocks moving or deleting a published tag and changing or deleting its release assets, while the release title and notes stay editable.

The maintainer decides how to recover from a broken release. Choose one:

- Point users to the previous working version in the release notes.
- Publish a corrective patch release: set the next version in `herdr-plugin.toml`, update [CHANGELOG.md](CHANGELOG.md), and repeat the steps above.

Withdrawal does not apply, because this project publishes no package to a registry.

Verify the chosen recovery: run the checks in [CONTRIBUTING.md](CONTRIBUTING.md) on the new commit, verify the new tag with `git verify-tag`, and verify the source archives of the new release. Publishing the tag, the release, or the release notes needs the maintainer's approval. Link the decision from the release notes.
