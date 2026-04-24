# Stack Research — nordvpn-actions

**Domain:** Public, MIT-licensed monorepo of composite GitHub Actions (ES/US/FR NordVPN country-egress actions), v1
**Researched:** 2026-04-24
**Overall confidence:** HIGH

## TL;DR

- Release tooling → `googleapis/release-please-action@v5.0.0` (the archived `google-github-actions/release-please-action` redirects here) driven by a manifest (`release-please-config.json` + `.release-please-manifest.json`) with one `release-type: simple` package per region; **separate PRs per action** so a change to `nordvpn-fr` never bumps `nordvpn-es`.
- Tag shape comes from release-please defaults: `include-component-in-tag: true` + `include-v-in-tag: true` + unspecified `tag-separator` produces `nordvpn-<region>-v<X.Y.Z>` — exactly the PROJECT.md contract. **Do not set `tag-separator: "@"`** (the canonical amarjanica example does, but it would give `nordvpn-es@v1.0.0` and break the pin contract).
- Floating major tag automation → a second job in the release-please workflow that reads `paths_released` (JSON array), iterates each released component, and force-pushes `<component>-v<MAJOR>` to the release SHA using plain `git tag -f` + `git push --force`. Requires `permissions.contents: write`; uses the default `GITHUB_TOKEN`.
- Linting → `reviewdog/action-actionlint@v1.72.0` (March 2026) for workflow YAML + inline shell (runs `shellcheck` internally on `run:` blocks) + `ludeeus/action-shellcheck@2.0.0` (Jan 2023, still current) pointed at `actions/**/scripts/*.sh` for the real Bash files. actionlint explicitly **does not** lint composite `action.yml` metadata — accept that limitation; shellcheck covers the scripts and actionlint covers every workflow + every `run:` block inside them.
- Dependabot `github-actions` ecosystem → single update block using the **`directories` (plural) key** (GA since 2024-06), enumerating `/`, `/actions/nordvpn-es`, `/actions/nordvpn-es/disconnect`, `/actions/nordvpn-us`, `/actions/nordvpn-us/disconnect`, `/actions/nordvpn-fr`, `/actions/nordvpn-fr/disconnect`. Dependabot understands the `# vX.Y.Z` trailing comment on SHA pins and will update both the SHA and the comment.
- CODEOWNERS → single-line `/actions/** @pau-vega` covers every current and future `actions/<new>/` addition recursively (a bare `/actions/*` would only match direct children, not nested files).
- Action pinning inside this repo's own workflows → SHA + `# vX.Y.Z` comment, no exceptions (OpenSSF Scorecard "pinned-dependencies" check, Dependabot-friendly).
- AGENTS.md → single root-level Markdown file, no schema, sections covering project overview, build/test commands, code style, testing instructions, security considerations, PR guidelines; the format is stewarded by the Agentic AI Foundation under the Linux Foundation and is used by 60k+ repos as of early 2026.
- Self-test workflow → `pull_request` (never `pull_request_target` for a repo that runs network egress with secrets), gated by `environment: Preview`, with an explicit `if: github.event.pull_request.head.repo.full_name == github.repository` fork-skip guard. Fork PRs print a skip message and exit 0.

---

## Recommended Stack

### Core Technologies (with pinned SHAs)

| Technology | Version | SHA (40-char) | Purpose | Why |
|------------|---------|---------------|---------|-----|
| `googleapis/release-please-action` | v5.0.0 (2026-04-22) | `45996ed1f6d02564a971a2fa1b5860e934307cf7` | Release PR creation, changelog generation, tag/release creation driven by Conventional Commits | **Canonical choice** — the `google-github-actions/release-please-action` repo was archived 2024-08-15 and the README points here. v5 is a Node 24 runtime bump over v4; **API is compatible with v4** (all docs still reference `@v4` syntax and it works unchanged on `@v5`). |
| `reviewdog/action-actionlint` | v1.72.0 (2026-03-31) | `6fb7acc99f4a1008869fa8a0f09cfca740837d9d` | Lints every YAML file in `.github/workflows/**` + runs `shellcheck` on every inline `run:` block | `actionlint` is the de facto standard for GitHub Actions workflow linting; the reviewdog wrapper is the most-used composite action for it (pins actionlint **v1.7.12** internally as of v1.72.0). |
| `ludeeus/action-shellcheck` | 2.0.0 (2023-01-29) | `00cae500b08a931fb5698e11e79bfbd38e612a38` | Runs `shellcheck` on standalone `.sh` files (the `scripts/connect.sh`, `install.sh`, etc.) | 2.0.0 is still current (no newer release in 3+ years — it's "done" software, not abandoned). Needed because `actionlint` only lints inline workflow shell, not standalone `.sh` files shipped inside each action. |
| `actions/checkout` | v6.0.2 (2026-01-09) | `de0fac2e4500dabe0009e67214ff5f5447ce83dd` | Standard checkout action used in the release, lint, and self-test workflows | v6 is the current major line (Node 24 runtime). Pinned by SHA with `# v6.0.2` comment per the pin-posture contract. |

**NOTE on SHA verification:** Every SHA above was resolved via `GET /repos/<owner>/<repo>/git/ref/tags/<tag>` on the GitHub API on 2026-04-24. For `reviewdog/action-actionlint@v1.72.0` the tag is annotated (type: `tag`), so the ref SHA `be0761e4c1bab7cfdfca56cd03d4bb6253e39a4a` points to a tag object; the dereferenced commit SHA `6fb7acc99f4a1008869fa8a0f09cfca740837d9d` is what goes in the `uses:` line. All four commit SHAs above are ready to paste.

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `release-please-config.json` schema | `$schema: https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json` | JSON Schema hint for editor autocomplete | Always include in the config `"$schema"` field so editors validate the file. |
| `actionlint` (binary, via the reviewdog action) | v1.7.12 (March 2026) | Workflow + inline-shell linter | Not installed directly — reviewdog action bundles it. If running locally, `brew install actionlint` or `go install github.com/rhysd/actionlint/cmd/actionlint@latest`. |
| `shellcheck` (binary, via ludeeus action) | v0.10.0 | Standalone shell script linter | Not installed directly — ludeeus action bundles it. For local runs, `brew install shellcheck`. |

### Development Tools (local)

| Tool | Purpose | Notes |
|------|---------|-------|
| `actionlint` (local install) | Run same check locally before pushing | `brew install actionlint` on macOS; `.actionlintignore` can exclude files; `actionlint -shellcheck=""` disables inline shellcheck if it's noisy. |
| `shellcheck` (local install) | Run same check locally before pushing | `brew install shellcheck`; `shellcheck -x actions/**/scripts/*.sh` reproduces the CI run. |
| `release-please` CLI (optional) | Simulate a release PR locally (`release-please release-pr --dry-run --config-file release-please-config.json --manifest-file .release-please-manifest.json --repo-url pau-vega/nordvpn-actions --token $GITHUB_TOKEN`) | `npx release-please@17.x`; useful for debugging commit-type mapping without pushing to `main`. |

---

## Prescriptive Configurations

### `release-please-config.json` (monorepo, 3 regions)

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "release-type": "simple",
  "bump-minor-pre-major": true,
  "bump-patch-for-minor-pre-major": true,
  "separate-pull-requests": true,
  "include-component-in-tag": true,
  "include-v-in-tag": true,
  "changelog-sections": [
    { "type": "feat",     "section": "Features" },
    { "type": "fix",      "section": "Bug Fixes" },
    { "type": "perf",     "section": "Performance Improvements" },
    { "type": "deps",     "section": "Dependencies" },
    { "type": "revert",   "section": "Reverts" },
    { "type": "docs",     "section": "Documentation" },
    { "type": "chore",    "section": "Miscellaneous",          "hidden": true },
    { "type": "refactor", "section": "Code Refactoring",       "hidden": true },
    { "type": "test",     "section": "Tests",                  "hidden": true },
    { "type": "build",    "section": "Build System",           "hidden": true },
    { "type": "ci",       "section": "Continuous Integration", "hidden": true }
  ],
  "packages": {
    "actions/nordvpn-es": { "component": "nordvpn-es" },
    "actions/nordvpn-us": { "component": "nordvpn-us" },
    "actions/nordvpn-fr": { "component": "nordvpn-fr" }
  }
}
```

**Why each field:**
- `"release-type": "simple"` — hoisted to the top level (inherited by each package). `simple` is the release-type for projects that **don't** use a package-manager manifest file (no `package.json`, no `Cargo.toml`); it just writes version to a `version.txt` inside each package dir and bumps it from Conventional Commits. Correct choice for composite actions where the only "version" source of truth is the Git tag.
- `"bump-minor-pre-major": true` + `"bump-patch-for-minor-pre-major": true` — while versions are `0.x.y`, `feat:` bumps patch (not minor) and breaking changes bump minor (not major), so `v0.x.y` doesn't prematurely hit `v1.0.0`. Once the first `v1.0.0` ships for a region, these options become no-ops for that region.
- `"separate-pull-requests": true` — **critical for this repo**: a fix in `nordvpn-fr` must not drag `nordvpn-es` and `nordvpn-us` into the same release PR. Each region releases independently. The amarjanica example sets this; most monorepo tutorials default to `false`, which would be wrong here.
- `"include-component-in-tag": true` (default) + `"include-v-in-tag": true` (default) + unspecified `tag-separator` → tag format `nordvpn-<region>-v<X.Y.Z>`. This is the PROJECT.md pin contract exactly.
- **Do NOT set `"tag-separator": "@"`** — the amarjanica canonical example uses `@` which yields `nordvpn-es@v1.0.0`, conflicting with the PROJECT.md contract.
- `changelog-sections` — mirrors the Angular Conventional Commits convention with `feat`/`fix`/`perf`/`deps`/`revert`/`docs` visible, everything else hidden. `deps` is explicit because Dependabot PRs should produce a "Dependencies" section entry, not a hidden chore entry. `docs` is **unhidden** because per-action README changes matter to consumers.
- `"packages"` — three entries, one per region. Each only needs `component` (path is the key). **No root package** (no `"."` entry) — the repo root isn't independently versioned; only per-action versions exist.

### `.release-please-manifest.json` (initial state, pre-first-release)

```json
{
  "actions/nordvpn-es": "0.0.0",
  "actions/nordvpn-us": "0.0.0",
  "actions/nordvpn-fr": "0.0.0"
}
```

Start every action at `0.0.0`. release-please rewrites this file on every merged release PR. The first release of each action will land at `0.1.0` (because `bump-minor-pre-major: true` means feat bumps patch pre-1.0 — but release-please's "first release" path is `0.1.0` regardless).

### `.github/workflows/release-please.yml` (release + floating major tag in one workflow)

```yaml
name: release-please

on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    outputs:
      releases_created: ${{ steps.release.outputs.releases_created }}
      paths_released:   ${{ steps.release.outputs.paths_released }}
    steps:
      - uses: googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0
        id: release
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json

  update-major-tags:
    needs: release-please
    if: ${{ needs.release-please.outputs.releases_created == 'true' }}
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Move floating major tag for each released component
        env:
          PATHS_RELEASED: ${{ needs.release-please.outputs.paths_released }}
        run: |
          set -euo pipefail
          git config user.name  'github-actions[bot]'
          git config user.email 'github-actions[bot]@users.noreply.github.com'

          # paths_released is a JSON array like: ["actions/nordvpn-es","actions/nordvpn-fr"]
          echo "$PATHS_RELEASED" | jq -r '.[]' | while read -r pkg_path; do
            component=$(basename "$pkg_path")                   # e.g. nordvpn-es
            tag_name="${component}--tag_name"                    # manifest-output key format
            version_key="${component}--version"                  # not used here but documented
            # Pull the per-component tag_name from the release-please step outputs via env
            full_tag="$(jq -r --arg k "$tag_name" '.[$k]' <<< '${{ toJson(needs.release-please.outputs) }}')" || true
            # Fallback: derive tag from the manifest + version we just released
            if [ -z "$full_tag" ] || [ "$full_tag" = "null" ]; then
              # Read bumped version straight out of the manifest file
              new_version=$(jq -r --arg k "$pkg_path" '.[$k]' .release-please-manifest.json)
              full_tag="${component}-v${new_version}"
            fi
            major="${full_tag%%.*}"                              # nordvpn-es-v1 from nordvpn-es-v1.2.3
            echo "Updating floating major: $major -> $full_tag"
            git tag -f "$major" "$full_tag"
            git push origin "$major" --force
          done
```

**Why this shape:**
- **Single workflow, two jobs** — keeps release creation and major-tag rewriting in one place, explicit `needs:` dependency. If `releases_created` is `false`, the second job is skipped.
- **Uses `paths_released` (JSON array), not `release_created`** — `release_created` is only set if a root (`.`) package is configured; this repo has no root package, so iterating `paths_released` is the correct shape. Don't use `releases_created` (plural, boolean) as the source of truth for iteration — it just tells you whether to run at all.
- **`fetch-depth: 0`** — needed on checkout so `git push` can see all refs.
- **`basename "$pkg_path"`** — maps `actions/nordvpn-es` → `nordvpn-es` (the component). With `include-component-in-tag: true` and the default `-` separator, the release tag is `nordvpn-es-v1.2.3` and the floating major is `nordvpn-es-v1`.
- **`full_tag="${component}-v${new_version}"`** — reads the just-bumped version directly out of `.release-please-manifest.json` (which is committed to `main` by the release PR merge, so it's the canonical source). The `steps.release.outputs[<component>--tag_name]` pattern also works, but on merge-commit-triggered runs the output may not be reliably surfaced across the job boundary, so the manifest-file read is the robust fallback.
- **No unambiguous bare `vN` tag** — because three regions share a monorepo, a bare `v1` tag would be ambiguous (is it `nordvpn-es-v1`? `nordvpn-fr-v1`?). Only per-region majors (`nordvpn-es-v1`, `nordvpn-us-v1`, `nordvpn-fr-v1`) get floated. Consumers `uses: pau-vega/nordvpn-actions/actions/nordvpn-es@nordvpn-es-v1`.
- **`GITHUB_TOKEN` is sufficient for force-pushing tags** — no PAT needed. The `permissions.contents: write` on the `update-major-tags` job is the only permission scope required.

### `.github/workflows/actions-lint.yml` (PR gate)

```yaml
name: actions-lint

on:
  pull_request:
    paths:
      - 'actions/**'
      - '.github/workflows/**'
      - '.github/actions/**'
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  actionlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
      - uses: reviewdog/action-actionlint@6fb7acc99f4a1008869fa8a0f09cfca740837d9d # v1.72.0
        with:
          reporter: github-pr-review
          fail_on_error: true
          level: error

  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
      - uses: ludeeus/action-shellcheck@00cae500b08a931fb5698e11e79bfbd38e612a38 # 2.0.0
        env:
          SHELLCHECK_OPTS: "-e SC1090 -e SC1091"
        with:
          scandir: ./actions
          severity: style
          check_together: 'yes'
```

**Why this shape:**
- **Two parallel jobs, not one** — actionlint and shellcheck check different surface areas; parallel runs give faster feedback and clearer failure attribution.
- **`fail_on_error: true` + `level: error`** on the reviewdog wrapper — the default is `warning`/annotate-only; we want a hard CI fail.
- **`scandir: ./actions`** on shellcheck — scopes to the action scripts only. Without this, it would also scan any stray `.sh` in the repo root and in `.github/`.
- **`severity: style`** — runs all shellcheck categories including style suggestions. Downgrade to `warning` only if noise becomes excessive.
- **`SHELLCHECK_OPTS: "-e SC1090 -e SC1091"`** — excludes SC1090/SC1091 (non-constant source paths) which fire falsely on scripts that `source "$RUNNER_TEMP/..."`-style dynamic paths.
- **Branch protection setup** — add both `actionlint` and `shellcheck` (job names) as required checks on `main`.

### `.github/dependabot.yml`

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directories:
      - "/"
      - "/actions/nordvpn-es"
      - "/actions/nordvpn-es/disconnect"
      - "/actions/nordvpn-us"
      - "/actions/nordvpn-us/disconnect"
      - "/actions/nordvpn-fr"
      - "/actions/nordvpn-fr/disconnect"
    schedule:
      interval: "weekly"
      day: "monday"
    commit-message:
      prefix: "deps"
    groups:
      actions:
        patterns: ["*"]
```

**Why this shape:**
- **`directories` (plural), not `directory`** — the plural form is GA since 2024-06-25 and supports wildcards. It collapses what used to be 7 separate `updates:` entries into one, massively simpler.
- **Enumerated (not globbed with `actions/**`)** — globbing works but explicit enumeration is easier to reason about when a new region is added (the Dependabot config change is part of the PR that adds the region, making it visible). Revisit if 10+ regions: glob pattern becomes worthwhile then.
- **Each entry is a directory containing an `action.yml`** — for the `github-actions` ecosystem, Dependabot scans `.github/workflows/` under `/` AND any `action.yml`/`action.yaml` at the listed directory roots. Hence why each region AND each region's `disconnect/` sub-action are listed.
- **`commit-message.prefix: "deps"`** — matches the `deps` type in the release-please `changelog-sections` config, so Dependabot PRs surface under "Dependencies" in the generated changelog.
- **`groups.actions.patterns: ["*"]`** — batches all action updates from a single Dependabot run into one PR, avoiding PR-spam when multiple actions update the same week.

### `.github/CODEOWNERS`

```
# Every file under actions/ — current and future — is owned by pau-vega.
/actions/** @pau-vega
```

**Why this exact pattern:**
- `/actions/*` matches files directly in `/actions/` but **not** recursively into subdirectories. That would fail to cover `/actions/nordvpn-es/action.yml`.
- `/actions/**` matches every file at every depth under `/actions/`. A new `/actions/nordvpn-de/` added later is automatically covered.
- **No trailing `@pau-vega` on a separate `*` line** — omitting a global fallback means PRs touching `LICENSE`, root `README.md`, or `.github/` don't auto-request review. For a solo-maintainer repo, that's the right default; add targeted rules later if PR-review policy tightens.

### `.github/workflows/self-test.yml` (fork-safe)

```yaml
name: self-test

on:
  pull_request:
    paths:
      - 'actions/**'
      - '.github/workflows/self-test.yml'
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  fork-check:
    runs-on: ubuntu-latest
    outputs:
      is_fork: ${{ steps.check.outputs.is_fork }}
    steps:
      - id: check
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ] \
             && [ "${{ github.event.pull_request.head.repo.full_name }}" != "${{ github.repository }}" ]; then
            echo "is_fork=true" >> "$GITHUB_OUTPUT"
            echo "::notice::Skipping self-test: fork PRs cannot access Preview environment secrets. Maintainer will run on a trusted branch."
          else
            echo "is_fork=false" >> "$GITHUB_OUTPUT"
          fi

  test-es:
    needs: fork-check
    if: needs.fork-check.outputs.is_fork == 'false'
    runs-on: ubuntu-latest
    environment: Preview
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
      - uses: ./actions/nordvpn-es
        with:
          nordvpn-username: ${{ secrets.NORDVPN_SERVICE_USERNAME }}
          nordvpn-password: ${{ secrets.NORDVPN_SERVICE_PASSWORD }}
      - name: Verify egress
        run: |
          curl -fsS https://ipinfo.io/json | jq -e '.country == "ES"'
      - uses: ./actions/nordvpn-es/disconnect
        if: always()

  # (identical test-us, test-fr jobs — omitted for brevity)
```

**Why `pull_request`, NOT `pull_request_target`:**
- `pull_request_target` runs in the base repo context with full secrets access. If a fork PR modifies any of the action's scripts, `pull_request_target` would execute the fork's malicious code with access to `NORDVPN_SERVICE_USERNAME`/`PASSWORD`. **Catastrophic.** This is the #1 GitHub Actions security anti-pattern (documented in the 2024 Trivy attack and the GitHub Security Lab's "dangerous workflow" check).
- `pull_request` runs in the fork's context and **does not expose secrets to fork PRs**, even with `environment: Preview` declared. The `fork-check` job is a belt-and-suspenders skip-with-notice to avoid the test jobs spinning up only to fail opaquely on missing secrets.
- `environment: Preview` — binds the secret scope. The `Preview` environment must be created in repo settings with `NORDVPN_SERVICE_USERNAME` and `NORDVPN_SERVICE_PASSWORD` scoped to it. Environment protection rules can require manual approval for non-`main` branches if even stricter gating is desired later.
- **No `pull_request_target` "allowlisted fork contributor" pattern** — deliberately omitted. The repo is small and solo-maintained; the complexity/risk ratio of an allowlist is wrong. Fork contributors open PRs, maintainer pulls them into a trusted branch for full run. Document that flow in AGENTS.md.

### Pin posture inside this repo

Every `uses:` line in every workflow of this repo uses the pinned-SHA form:

```yaml
- uses: googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0
- uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
- uses: reviewdog/action-actionlint@6fb7acc99f4a1008869fa8a0f09cfca740837d9d # v1.72.0
- uses: ludeeus/action-shellcheck@00cae500b08a931fb5698e11e79bfbd38e612a38 # 2.0.0
```

**Why:**
- **OpenSSF Scorecard** "pinned-dependencies" check requires 40-char SHAs. Version tags (`@v5`) are mutable; a compromised upstream can silently move `v5` to malicious code.
- **Dependabot reads the trailing `# vX.Y.Z` comment** and updates both the SHA and the comment in PRs. Without the comment, PRs would be unreadable ("SHA changed from abc to def, no clue why").
- **This repo ships a security-sensitive action** — it must model the pin posture it preaches to consumers.

### `AGENTS.md` (agent contributor guide, root-level)

Per the 2026 convention stewarded by the Agentic AI Foundation under the Linux Foundation (over 60k public repos as of January 2026), `AGENTS.md` is a plain Markdown file at the repo root with no required schema. Converged-on sections for this repo:

```markdown
# AGENTS.md

## Project Overview
[What this repo is — composite GitHub Actions monorepo, region list, consumer form]

## Development Environment
[How to clone, what's needed locally: actionlint, shellcheck, gh CLI, jq]

## Build and Test Commands
[Local run of actionlint + shellcheck. Note: self-test requires NordVPN creds + is not runnable locally.]

## Code Style
[Bash: set -euo pipefail; shellcheck-clean; 2-space YAML indent; action.yml uses canonical input/output casing]

## Testing Instructions
[Lint runs on every PR. Self-test runs on push to main and non-fork PRs. Fork PRs skip self-test with a notice.]

## Release Process
[Conventional Commits → release-please PR → merge → tagged release + floating major tag moved]

## Security Considerations
[SHA-pinned actions; no pull_request_target; secrets scoped to Preview environment; auth file chmod 0600]

## PR Guidelines
[Commit format: `type(scope): subject` where scope is `nordvpn-<region>`. One region per PR when possible.]

## For AI Agents
[Explicit expectations: run actionlint + shellcheck locally before pushing; use Conventional Commits; do not touch .release-please-manifest.json or CHANGELOG.md files — release-please owns them; do not commit secrets]
```

## Installation

None required at the language-toolchain level — this is a pure Bash composite-action repo, no Node/Go/Python/Rust runtime involvement. The three external tools (`actionlint`, `shellcheck`, `release-please`) are GitHub Actions or bundled inside them; local dev gets them via Homebrew:

```bash
# Optional local toolchain (for running the same checks locally as CI)
brew install actionlint shellcheck jq gh
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `googleapis/release-please-action@v5.0.0` | `google-github-actions/release-please-action` | **Never.** Archived 2024-08-15, readme redirects here. |
| `googleapis/release-please-action` | `semantic-release` | When shipping an npm package from a single-package repo. `semantic-release` is Node-ecosystem-native; for a monorepo of composite actions with no npm publish step, `release-please`'s manifest model is better. |
| `googleapis/release-please-action` | `release-drafter` | When you only want draft release notes without version bumping or tag creation. Not suitable here — we need tags created for the `uses:` pin contract. |
| `release-type: simple` | `release-type: generic` | `generic` is for languages release-please doesn't have a first-class strategy for (requires `extra-files` with `generic` updater annotations in each file). `simple` is specifically the "no manifest file to parse, just a version.txt" strategy — exactly what a composite-action dir needs. `simple` wins. |
| `release-type: simple` | `release-type: node` | Only valid if each action dir had a `package.json`. Composite actions don't; adding a `package.json` just to satisfy release-please is noise. |
| `separate-pull-requests: true` | `separate-pull-requests: false` (one PR per merge) | `false` makes sense when components are linked or always release together (e.g., workspace packages with shared version). For this repo, independent regions should release independently — `true` is correct. |
| `include-component-in-tag: true` (default, with default `-` separator) | `tag-separator: "@"` (as amarjanica example) | `@` yields `nordvpn-es@v1.0.0` which fights the PROJECT.md `nordvpn-<region>-vX.Y.Z` contract and confuses consumers used to the `<component>-v<version>` GitHub Actions monorepo convention. Stick with the default `-`. |
| `reviewdog/action-actionlint` | Raw `rhysd/actionlint` binary (download + run manually) | When you need very custom output parsing. The reviewdog wrapper gets PR-inline annotations for free via reviewdog's GitHub PR review reporter. No reason to go manual. |
| `ludeeus/action-shellcheck@2.0.0` | `composite-action-lint` (bettermarks/composite-action-lint) | If lint of `action.yml` metadata itself becomes critical. `actionlint` does NOT validate composite `action.yml` (known gap); `composite-action-lint` fills it but adds a third linter to maintain. Defer until there's a real pain point. |
| `pull_request` + `environment: Preview` + fork-skip | `pull_request_target` with allowlist | Allowlist adds a maintainer-approval gate but exposes secrets to fork code if the allowlist check is misconfigured. Not worth the complexity for v1. |
| `dependabot directories` (plural) + enumerate | Multiple separate `updates:` blocks for github-actions | Pre-2024-06, plural didn't exist; you'd have 7 nearly-identical blocks. Today's plural syntax collapses them. Use it. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `google-github-actions/release-please-action` | Archived 2024-08-15; README says development moved. Using it now means no security updates or bug fixes. | `googleapis/release-please-action@v5.0.0` (SHA: `45996ed1f6d02564a971a2fa1b5860e934307cf7`) |
| `googleapis/release-please-action@main` or `@v4` floating tag | Defeats SHA pinning; a compromised upstream moves the tag and you're owned on the next workflow run. | `@<40-char-SHA> # v5.0.0` |
| `pull_request_target` for anything that runs code from a PR | Executes fork code with base-repo secret access. One misconfiguration → credential exfiltration. See the February 2026 "Fork + pull_request_target AWS compromise" disclosure for a fresh example. | `pull_request` with a fork-skip guard. If you truly need to comment back on fork PRs, have the `pull_request` job write a JSON artifact and a separate `workflow_run`-triggered workflow does the commenting. |
| `release-type: generic` | Requires manual `extra-files` annotation in the action's files. Noise. | `release-type: simple` — writes a single `version.txt` per package. |
| Bare major tags like `v1` in this repo (alongside per-region `nordvpn-es-v1`) | Ambiguous in a monorepo of 3+ actions. Breaks the consumer mental model. | Only per-region major floats: `nordvpn-es-v1`, `nordvpn-us-v1`, `nordvpn-fr-v1`. |
| `shellcheck` via `apt-get install shellcheck` inside a workflow step | Fragile, slow, depends on runner's current shellcheck version. | `ludeeus/action-shellcheck@2.0.0` SHA-pinned. |
| `actionlint` inside workflow with `go install` | Build overhead + version drift. | `reviewdog/action-actionlint` SHA-pinned. |
| Global `*` catchall in CODEOWNERS | Forces self-review on every PR, including LICENSE/root-README typo fixes. | Scope CODEOWNERS to `/actions/** @pau-vega` only. |
| `tag-separator: "@"` | Generates `nordvpn-es@v1.0.0` — fights the `<component>-v<version>` GitHub Actions monorepo convention and the PROJECT.md pin contract. | Omit `tag-separator` entirely (default is `-`). |

## Stack Patterns by Variant

**If a 4th region is added later (e.g., `nordvpn-de`):**
- Add `"actions/nordvpn-de": { "component": "nordvpn-de" }` to `release-please-config.json`.
- Add `"actions/nordvpn-de": "0.0.0"` to `.release-please-manifest.json`.
- Add `/actions/nordvpn-de` and `/actions/nordvpn-de/disconnect` to `dependabot.yml` directories list.
- No workflow changes — `paths_released` iteration auto-picks it up.
- No CODEOWNERS change — `/actions/**` covers it.

**If marketplace publication is added post-v1:**
- Marketplace requires one `action.yml` at the repo root OR one listing per repo. A single monorepo cannot publish 3 separate listings from 3 subdirectories.
- Option A: split into 3 repos (`pau-vega/nordvpn-es`, `pau-vega/nordvpn-us`, `pau-vega/nordvpn-fr`) at that point — accept the tooling duplication.
- Option B: publish only one region to marketplace, leave the others as SHA-pinned `uses:` references.
- Option C: generate a root `action.yml` that dispatches to a region input (changes the `uses:` contract — **breaks v1 consumers**; would need v2 semver bump on all three regions).
- **Recommendation:** re-decide at the marketplace milestone; don't optimize for it now.

**If OIDC-based authentication replaces static NordVPN credentials (unlikely, but hypothetically):**
- `permissions.id-token: write` on the self-test job.
- Drop `environment: Preview` (no more secrets to scope).
- Fork-safety no longer relevant — OIDC tokens are scoped to the workflow run.
- **Not applicable to NordVPN in 2026** — they don't issue OIDC tokens. Static service creds are the only option.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| `googleapis/release-please-action@v5.0.0` | Node 24 runner (default on `ubuntu-latest` since late 2025) | The only v4→v5 breaking change. `ubuntu-latest` already ships Node 24 in the runner image; no action required. |
| `googleapis/release-please-action@v5.0.0` | `release-please` core v17.6.0 | Bundled inside the action; no separate pin needed. |
| `reviewdog/action-actionlint@v1.72.0` | `actionlint` v1.7.12 | Bundled. To upgrade actionlint, upgrade the reviewdog action. |
| `ludeeus/action-shellcheck@2.0.0` | `shellcheck` v0.10.0 | Bundled. Action is stable, not abandoned — no upgrade path needed. |
| `actions/checkout@v6.0.2` | Node 24 runner | v5/v6 both work; v6 is current. |
| `release-please-config.json schema` | Draft-07 | Schema URL in config enables editor validation. |

## Sources

### Context7
- `/googleapis/release-please` — monorepo configuration, simple release-type, tag-separator behavior, changelog-sections shape, schema fields with defaults
- `/googleapis/release-please-action` — outputs contract (`paths_released`, `<path>--tag_name`, `<path>--release_created`), v4/v5 API, monorepo examples

### Official Documentation (HIGH confidence)
- [release-please manifest-releaser.md](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md) — manifest-driven monorepo config
- [release-please config.json schema](https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json) — authoritative default values (`include-component-in-tag` defaults `true`, `include-v-in-tag` defaults `true`)
- [googleapis/release-please-action README](https://github.com/googleapis/release-please-action) — outputs table, per-path output format
- [googleapis/release-please-action v5.0.0 release](https://github.com/googleapis/release-please-action/releases/tag/v5.0.0) — Node 24 runtime bump is the only v4→v5 breaking change
- [google-github-actions/release-please-action (archived)](https://github.com/google-github-actions/release-please-action) — explicit redirect to googleapis/
- [GitHub Docs: Dependabot options reference](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference) — `directories` (plural) vs `directory` semantics, wildcards
- [GitHub Changelog: directories key GA](https://github.blog/changelog/2024-06-25-simplified-dependabot-yml-configuration-with-multi-directory-key-directories-and-wildcard-glob-support/) — feature dates
- [GitHub Docs: About code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) — glob semantics
- [rhysd/actionlint checks](https://github.com/rhysd/actionlint/blob/main/docs/checks.md) — confirms composite `action.yml` metadata is **not** linted (gap)
- [agents.md](https://agents.md/) — format steward and section conventions

### Community / Reference Implementations (MEDIUM confidence)
- [amarjanica/release-please-monorepo-example](https://github.com/amarjanica/release-please-monorepo-example) — canonical monorepo template (note: uses `@` separator which we diverge from)
- [cicirello/ade1d559a… gist](https://gist.github.com/cicirello/ade1d559a89104140557389365154bc1) — floating major tag workflow pattern
- [cicirello dev.to article](https://dev.to/cicirello/automate-updating-major-release-tag-on-new-releases-of-a-github-action-cci) — same pattern, narrative

### Security References (HIGH confidence)
- [OSSF Scorecard pinned-dependencies check](https://scorecard.dev/) — SHA-pinning rationale
- [GitHub Docs: Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use) — pinned-action guidance
- [GitHub Blog: Fork + pull_request_target attack vectors](https://github.blog/news-insights/product-news/github-actions-improvements-for-fork-and-pull-request-workflows/) — why `pull_request_target` is unsafe for fork-runnable workflows
- [Medium: Exploiting Fork and pull_request_target to Compromise AWS, Feb 2026](https://medium.com/@sadi.zane/exploiting-fork-and-pull-request-target-to-compromise-aws-3d3e77873b27) — fresh real-world case

### GitHub API (SHA verification)
- `GET /repos/googleapis/release-please-action/git/ref/tags/v5.0.0` → `45996ed1f6d02564a971a2fa1b5860e934307cf7`
- `GET /repos/actions/checkout/git/ref/tags/v6.0.2` → `de0fac2e4500dabe0009e67214ff5f5447ce83dd`
- `GET /repos/reviewdog/action-actionlint/git/ref/tags/v1.72.0` → annotated tag `be0761e4…`, dereferenced commit `6fb7acc99f4a1008869fa8a0f09cfca740837d9d`
- `GET /repos/ludeeus/action-shellcheck/git/ref/tags/2.0.0` → `00cae500b08a931fb5698e11e79bfbd38e612a38`

All SHAs verified live on 2026-04-24.

## Confidence Levels per Recommendation

| Recommendation | Confidence | Rationale |
|----------------|------------|-----------|
| `googleapis/release-please-action@v5.0.0` over any alternative | **HIGH** | Archived predecessor confirmed via page; v5.0.0 confirmed via GitHub API; Context7 + README triangulate |
| Use `release-type: simple` per region | **HIGH** | Schema, docs, and rationale all align; no package-manager manifest exists to drive other release types |
| `separate-pull-requests: true` | **HIGH** | Independent regions; confirmed as correct for this shape by multiple monorepo guides |
| Default `-` separator (no `tag-separator` field) yields `<component>-v<version>` | **HIGH** | Docs + schema + release-please source behavior confirm default |
| `paths_released` JSON array + iterate pattern for floating major tags | **HIGH** | Documented output contract, manifest-file fallback is robust |
| `reviewdog/action-actionlint@v1.72.0` SHA | **HIGH** | GitHub API confirmed, dereferenced annotated tag |
| `ludeeus/action-shellcheck@2.0.0` SHA | **HIGH** | GitHub API confirmed; action is stable (3+ years no release) — stability, not abandonment |
| `actions/checkout@v6.0.2` SHA | **HIGH** | GitHub API confirmed |
| `actionlint` does NOT lint composite `action.yml` metadata — accept the gap | **HIGH** | Explicitly documented in actionlint repo's checks.md |
| `dependabot` `directories` (plural) with enumerated entries | **HIGH** | GA since 2024-06, official docs; works as described |
| `/actions/** @pau-vega` CODEOWNERS pattern | **HIGH** | Standard glob semantics, matches docs exactly |
| `pull_request` + `environment: Preview` + fork-skip guard (not `pull_request_target`) | **HIGH** | Widely documented security guidance; recent real-world exploits reinforce |
| Floating major tag shell snippet (`basename`, `jq -r '.[]'`, `git tag -f`) | **MEDIUM** | Pattern is well-known and my composition from documented outputs is correct, but the exact fallback (reading `.release-please-manifest.json` for the bumped version) is a composition specific to this repo — expect minor tweaks during Phase 5 implementation |
| AGENTS.md section list | **MEDIUM** | Format is schema-free so "what sections to use" is convention, not spec; the list above matches the 60k+ repos pattern but is not enforced |
| Not floating a bare `v1` tag | **HIGH** | Monorepo disambiguation rationale is unambiguous |
| `bump-minor-pre-major: true` + `bump-patch-for-minor-pre-major: true` | **MEDIUM** | Reasonable default for pre-1.0 actions; if you prefer early v1.0 on first stable release, drop both — depends on your semver philosophy |

---

*Stack research for: public monorepo of composite GitHub Actions (nordvpn-actions v1, ES/US/FR)*
*Researched: 2026-04-24*
