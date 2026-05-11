<!--
Thanks for the PR. Please fill the sections below — they mirror the checks the maintainer applies before merging. Drive-by typo / doc / lint fixes can keep this short; substantive changes need every box ticked.
-->

## Summary

<!-- One-paragraph description of what changes and why. -->

## Affected region(s)

<!-- Tick exactly one of the top three for region-specific changes. Cross-cutting? Tick "Not region-specific". -->

- [ ] `nordvpn-es` (Spain)
- [ ] `nordvpn-us` (United States)
- [ ] `nordvpn-fr` (France)
- [ ] Not region-specific (CI, docs, release tooling, etc.)

> One region per PR. Mixing ES + US + FR splits release-please across multiple PRs and the changelog gets messy. See [`.github/CONTRIBUTING.md`](./CONTRIBUTING.md) §What counts as a good PR.

## Type of change

- [ ] `feat` — new action surface, new region, new output
- [ ] `fix` — bug in existing behavior
- [ ] `docs` — README / AGENTS.md / action README / this template
- [ ] `deps` — dependency bump
- [ ] `lint` — linter config, workflow YAML hygiene, no behavior change
- [ ] `chore` — everything else
- [ ] **Breaking change** (frozen v1 contracts — almost never acceptable; if ticked, explain below)

## Conventional Commit scope used

<!-- Paste the actual subject line from your commit(s), e.g. `fix(nordvpn-us): retry on transient API 503`. -->

```
```

## Checklist

- [ ] Followed [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) — type and scope match the affected region or `lint` / `chore`.
- [ ] `actionlint .github/workflows/*.yml` runs clean locally (or CI is green on this PR).
- [ ] `shellcheck actions/**/scripts/*.sh` runs clean locally (or CI is green).
- [ ] Did NOT hand-edit `.release-please-manifest.json` or `actions/*/CHANGELOG.md` — release-please owns those files.
- [ ] All new `uses:` lines pin a 40-char SHA with a trailing `# vX.Y.Z` comment. No `@main`, no `@v5`.
- [ ] If a new workflow was added, it has a top-level `permissions:` block and per-job `timeout-minutes`.
- [ ] If `actions/**/scripts/**` was touched, no `set -x` was introduced. (`set -x` leaks secrets past GitHub's exact-match masking — see [`AGENTS.md`](../AGENTS.md) §Banned constructs.)
- [ ] If this changes a frozen v1 contract (input names, output names, the six-output shape), the body below explains the migration path.

## Self-test

> Fork PRs cannot reach the `Preview` environment secrets — `self-test.yml` will skip with a `::notice::`. The maintainer re-runs from a trusted branch before merging non-trivial changes. If you can run the self-test from your own fork that has its own `NORDVPN_SERVICE_*` secrets, paste the run link below.

- Self-test run link (optional):

## Related issues / discussions

<!-- Closes #NN — or "no related issue" for drive-by fixes. -->
