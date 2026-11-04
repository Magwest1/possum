# Contributing

Thanks for helping out! Possum is meant to stay small, so please open an issue to discuss new
features before you start working on one.

## Development

Requirements: macOS 13+, Swift 6 (Xcode 16+ or the Command Line Tools).

```bash
make test   # unit tests
make run    # build an ad-hoc signed Possum.app for this Mac and launch it
```

The helper registers via `SMAppService`, so it must run from inside the app bundle. Use
`make run` rather than `swift run`.

## Commits and releases

- PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `docs:`, `ci:`, `chore:` …). PRs are squash-merged, so the title becomes
  the commit message.
- [release-please](https://github.com/googleapis/release-please) turns those commits into a
  release PR. Merging that PR builds, signs, notarizes and publishes a release.
  See [docs/RELEASING.md](docs/RELEASING.md).
