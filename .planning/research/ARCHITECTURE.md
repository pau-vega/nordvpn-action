# Architecture Research

**Domain:** Multi-action GitHub Actions monorepo (composite actions, per-region NordVPN egress)
**Researched:** 2026-04-24
**Confidence:** HIGH

This document focuses on how polished multi-action monorepos are structured, the boundaries between components, and the dependency order that drives the build plan for `pau-vega/nordvpn-actions` v1 (ES port + US/FR net-new). Conclusions are drawn from real-world exemplars cited at file-path level.

---

## Repository-Level Architecture

### System Overview — File Tree View

```
nordvpn-actions/                             [repo root — public, MIT]
│
├── LICENSE                                  [MIT — required for MIT distribution]
├── README.md                                [index of shipped actions + pin-form guidance]
├── AGENTS.md                                [AI-agent contributor guide — matches source PR pattern]
├── CODEOWNERS                               [scopes /actions/** to @pau-vega]
│
├── .github/
│   ├── release-please-config.json           [monorepo release config — packages map]
│   ├── release-please-manifest.json         [per-path version map — canonical version source]
│   ├── dependabot.yml                       [watches /, each actions/nordvpn-<r>, each /disconnect]
│   └── workflows/
│       ├── actions-lint.yml                 [actionlint + shellcheck — cheap gatekeeper]
│       ├── release-please.yml               [release-please + floating-major-tag job]
│       └── self-test.yml                    [per-region matrix → real NordVPN via Preview env]
│
└── actions/                                 [canonical location — every published composite action]
    ├── nordvpn-es/                          [port from Tutellus PR #159 — reference impl]
    │   ├── action.yml                       [composite: inputs, runs.steps call ./scripts/*.sh]
    │   ├── README.md                        [Inputs/Outputs/Usage/Versioning/Troubleshooting/Rotation]
    │   ├── CHANGELOG.md                     [release-please managed — do NOT edit by hand]
    │   ├── scripts/
    │   │   ├── install.sh                   [apt-get openvpn + openvpn-systemd-resolved, assert PATH]
    │   │   ├── connect.sh                   [write 0600 auth, openvpn --daemon, poll tun0]
    │   │   └── verify-country.sh            [dual-provider geo check, emit outputs]
    │   ├── vpn/
    │   │   └── nordvpn-es.ovpn              [bundled profile — reproducibility anchor]
    │   └── disconnect/                      [SIBLING sub-action — composite post: workaround]
    │       ├── action.yml                   [composite: calls scripts/disconnect.sh]
    │       ├── README.md                    [2 lines: "invoke with if: always()"]
    │       └── scripts/
    │           └── disconnect.sh            [pkill openvpn; rm -f $AUTH_FILE]
    │
    ├── nordvpn-us/                          [net-new — same shape as -es, US .ovpn]
    │   └── (mirror of nordvpn-es tree)
    │
    └── nordvpn-fr/                          [net-new — same shape as -es, FR .ovpn]
        └── (mirror of nordvpn-es tree)
```

**Canonical layout justification:** `actions/<name>/` at root is the pattern used by every production multi-action monorepo surveyed:

- `github/codeql-action` puts sub-actions at repo root (`init/`, `analyze/`, `upload-sarif/`, `autobuild/`, `resolve-environment/`, `start-proxy/`, `setup-codeql/`) — but that's because CodeQL predates the `actions/` convention and is a JS action family, not composite. [[codeql-action](https://github.com/github/codeql-action)]
- `loozhengyuan/actions` places composite actions at repo root (`setup-hugo/`, `setup-kicad/`, `setup-kicad-library-utils/`, `setup-zephyr-sdk/`) because each is a top-level concern with no shared namespace. [[loozhengyuan/actions](https://github.com/loozhengyuan/actions)]
- `MitaWinata/monorepo_independent_releases` puts packages under `model/a/`, `model/b/` — a nested layout for release-please independence. [[source](https://github.com/MitaWinata/monorepo_independent_releases)]
- GitHub's own community-recommended pattern (Discussions #141741, #24990) supports both root-level and nested, with nested (`actions/<name>/`) preferred when the repo ships *only* actions and wants namespace clarity in `uses:` references. [[Discussion #141741](https://github.com/orgs/community/discussions/141741)]

**Why `actions/nordvpn-<region>/` (nested) wins here:**

1. **`uses:` line readability:** `pau-vega/nordvpn-actions/actions/nordvpn-es@<ref>` is self-describing. Root-level `pau-vega/nordvpn-actions/nordvpn-es@<ref>` would work identically for GitHub's resolver but reads like a repo-name-within-a-repo-name.
2. **Headroom for non-action content:** Root reserves space for `examples/`, `scripts/` (repo-wide tooling), or future `workflows/` (reusable workflow exports) without mixing namespaces.
3. **Matches the source PR's already-working shape:** Tutellus PR #159 uses `actions/nordvpn-es/`, so the port is file-path-preserving — zero re-mapping in scripts, zero reference drift in any inline docs copied over.
4. **CODEOWNERS simplicity:** `/actions/ @pau-vega` catches every action without touching future non-action roots. One line.

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `actions/nordvpn-<region>/action.yml` | Public contract: declares inputs, outputs, `runs: using: composite`, orchestrates script calls | Composite action YAML, ~50 lines |
| `actions/nordvpn-<region>/scripts/install.sh` | Install OpenVPN + `openvpn-systemd-resolved`, assert PATH | `apt-get update && apt-get install -y`, `command -v openvpn` |
| `actions/nordvpn-<region>/scripts/connect.sh` | Write auth file, start OpenVPN daemon, poll `tun0` for IPv4 | `0600` umask write, `openvpn --daemon`, bounded retry loop |
| `actions/nordvpn-<region>/scripts/verify-country.sh` | Two-provider geo check, fail closed, emit diagnostics outputs | `curl ipinfo.io`, `curl ifconfig.co`, `jq`, `$GITHUB_OUTPUT` writes |
| `actions/nordvpn-<region>/vpn/nordvpn-<region>.ovpn` | Bundled, reproducibility-anchored server profile | Static file, checked in, drift-accepted |
| `actions/nordvpn-<region>/disconnect/action.yml` | Public contract for teardown (sibling, not child) | Composite action, 1 step: `bash scripts/disconnect.sh` |
| `actions/nordvpn-<region>/disconnect/scripts/disconnect.sh` | Kill OpenVPN, remove auth file, idempotent | `sudo pkill openvpn \|\| true; rm -f $AUTH_FILE` |
| `.github/workflows/actions-lint.yml` | Cheap gatekeeper — runs on every PR touching `actions/**` or workflows | `rhysd/actionlint` + `shellcheck` |
| `.github/workflows/release-please.yml` | Compute next version per-action, open release PR, on merge → tag + GitHub Release + floating major | `googleapis/release-please-action@v4` + custom tag-move step |
| `.github/workflows/self-test.yml` | End-to-end proof that a given `nordvpn-<r>` actually egresses from `<r>` | Per-region matrix, `environment: Preview`, fork-skip guard |
| `.github/release-please-config.json` | Packages map: path → release-type, component, changelog-sections | JSON, hand-edited at milestone boundaries |
| `.github/release-please-manifest.json` | Source of truth for current version per package | JSON, updated *by release-please*, never hand-edited |

---

## Sub-Action Layout — The `disconnect/` Sibling Pattern

### The Constraint

GitHub composite actions do **not** support `pre:` / `post:` runs. This is confirmed by GitHub staff in [Discussion #26743](https://github.com/orgs/community/discussions/26743) ("composite action as just a combination of some run steps") and is an open, unactioned feature request at [actions/runner#1478](https://github.com/actions/runner/issues/1478). The Tailscale and golfzaptw NordVPN actions both sidestep this by being JavaScript actions — not composite. Since this project is explicitly composite-only, the constraint is load-bearing.

### The Pattern

Every region ships a **sibling sub-action** named `disconnect/`:

```yaml
# Consumer workflow — the required invocation pattern
steps:
  - uses: pau-vega/nordvpn-actions/actions/nordvpn-es@v1   # connect
    with:
      username: ${{ secrets.NORDVPN_SERVICE_USERNAME }}
      password: ${{ secrets.NORDVPN_SERVICE_PASSWORD }}

  - run: curl https://api.example.com   # country-gated work

  - uses: pau-vega/nordvpn-actions/actions/nordvpn-es/disconnect@v1
    if: always()                        # required — teardown on any prior failure
```

**Why "sibling" not "child":**

- **Composite actions cannot `uses:` a nested local action with a relative path** in a way that's reliable across consumer repos without an extra `checkout` step. Discussion #41927 documents the sharp edge: "Calling a sibling composite action using the same ref" requires the consumer to have checked out the full monorepo, which is a non-starter for a published action. The sibling pattern pushes the invocation back to the consumer's workflow, where `uses:` at the workflow level resolves cleanly via GitHub's action resolver.
- **`if: always()` works at the workflow step level, not inside a composite step.** This is the critical reason the caller must do the invocation — only the caller's workflow has the scope to guarantee `if: always()` runs after a prior step failure.
- **Zero state-sharing between connect and disconnect.** `disconnect.sh` reads `$RUNNER_TEMP/nordvpn-auth` (well-known path) and `pkill`s by process name. It does not depend on any output, env var, or file that `connect.sh` must export. This decoupling is intentional: an orphan disconnect (connect never ran, or crashed before writing the auth file) succeeds silently with `|| true` guards.

**Documentation burden:** Each action's README must state this pattern prominently. AGENTS.md and the root README repeat it. There is no code-level enforcement — a consumer who forgets `if: always()` or the disconnect step will leak an OpenVPN process into the runner, which dies with the ephemeral runner anyway but risks leaving secrets on disk if something were persistent. The 0600 perms and `$RUNNER_TEMP` placement make that acceptable, not elegant.

### Real-world precedent for sibling sub-actions

- `google-github-actions` uses one-repo-per-action and doesn't face this (one-shot install-style actions).
- `actions/cache` family (`actions/cache/save`, `actions/cache/restore`) is the closest canonical analog — two related actions published as sub-paths of one repo, invoked separately by the consumer. They aren't strictly "sibling" (they live inside `actions/cache` as sub-paths), but the pattern — caller invokes two sub-paths separately, second one `if: always()` — is identical.
- `loozhengyuan/actions` does not need teardown; its setup actions are one-shot installs.
- `github/codeql-action` is JS and uses `post:` inside each action (init's `post:` resolves to `../lib/init-action-post.js`, confirmed in its `action.yml`) — not applicable here.

The sibling pattern for `disconnect/` is therefore an accepted, documented workaround rather than a canonical GitHub-published pattern. It is documented in this repo as the shape for every region.

---

## Shared Utilities — Duplicate, Don't Abstract (For v1)

### The question: `actions/_shared/scripts/` or triplicate?

For three regions with identical install/connect/verify/disconnect scripts differing only in the bundled `.ovpn` and the expected ISO-2 code, abstraction is tempting. For v1, **duplication is correct**.

**Why duplicate:**

1. **`uses:` path isolation.** A consumer doing `pau-vega/nordvpn-actions/actions/nordvpn-es@v1.2.3` expects that ref to pin every file the action needs. If `nordvpn-es` reaches into `actions/_shared/scripts/`, the consumer's pin doesn't cover those shared scripts — they're resolved at whatever SHA the *repo* checkout lands on, which is the tag's SHA, but only because GitHub's resolver checks out the whole repo for composite actions. This works, but it creates an invisible version-coupling: a breaking change in a shared script forces a major bump on *every* region, even if only one cares. With three regions this is usually fine; with ten it becomes a release-coordination headache.
2. **Release-please config simplicity.** If each action is self-contained, `packages` map is three clean entries. If there's a `_shared/`, release-please needs either an extra package entry for `_shared` (with its own version nobody consumes) or the shared scripts need to live *outside* any `packages` path, which means they don't participate in release-please's diff detection and no changelog entry is generated when they change. Both options add surface.
3. **Conventional-commit clarity.** `fix(nordvpn-es): foo` is unambiguous. `fix(_shared): foo` forces the author to think about which regions are affected and whether to `fix(nordvpn-es,nordvpn-us,nordvpn-fr)` or let release-please figure it out (it can, via the `extra-files`/`packages` config, but it's an extra cognitive load).
4. **Port fidelity.** The Tutellus source already has the scripts at `actions/nordvpn-es/scripts/`. Preserving that layout for ES and mirroring for US/FR is a literal file-copy. Refactoring to a shared helper at port time conflates two changes (re-homing + abstracting) in one milestone, doubling review burden and risk.

**When to revisit:** At 5+ regions, or on the first bug that has to be fixed in three places, introduce `actions/_shared/scripts/`. Track as a post-v1 candidate, not a v1 requirement.

**Confidence:** HIGH. This matches how `github/codeql-action` organized its sub-actions before it needed shared code (each sub-action referenced `../lib/*.js` only once they hit that pain), and how `google-github-actions` organizes its *separate-repo* actions (each independent, no shared code in-repo).

---

## Bundled Artifacts — `vpn/` Subdirectory

Each action bundles its region's `.ovpn` profile at `actions/nordvpn-<region>/vpn/nordvpn-<region>.ovpn`. Three places this could live; this is the right one.

| Location | Verdict | Reason |
|----------|---------|--------|
| `actions/nordvpn-<region>/vpn/<name>.ovpn` (chosen) | Correct | Self-contained under the action's directory; pinned by the action's tag; release-please detects changes in its diff path filter. |
| `actions/nordvpn-<region>/config/<name>.ovpn` | Acceptable, less precise | `config/` is generic; `vpn/` names the concern. Matches Tutellus source PR #159. |
| `configs/<region>.ovpn` at repo root | Wrong | Breaks self-containment; a shared-config bump invalidates every region's cache/pin even if nothing else changed. Same pitfalls as `_shared/` above. |

**Naming:** File is `nordvpn-<region>.ovpn` (not `<region>.ovpn` or `profile.ovpn`) for grep-ability in diffs and clarity when debugging.

---

## CI Workflow Architecture

### Workflow 1: `actions-lint.yml` — The Gatekeeper

```yaml
name: actions-lint
on:
  pull_request:
    paths:
      - 'actions/**'
      - '.github/workflows/**'
  push:
    branches: [main]
    paths:
      - 'actions/**'
      - '.github/workflows/**'
permissions:
  contents: read
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>  # v4
      - name: Run actionlint (embeds shellcheck)
        run: |
          bash <(curl -sSfL https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)
          ./actionlint -color
      # shellcheck strict on every shell script under actions/
      - name: shellcheck strict
        run: |
          find actions -type f -name '*.sh' -print0 \
            | xargs -0 shellcheck --severity=style --external-sources
```

**Key architectural choices:**

- **Path filter is mandatory.** Without it, every docs-only PR triggers a lint run. Filter on `actions/**` and `.github/workflows/**` (workflows self-lint their own edits).
- **actionlint embeds shellcheck for inline `run:` scripts.** actionlint pipes `run:` script bodies through shellcheck automatically when shellcheck is on PATH. [[actionlint docs](https://github.com/rhysd/actionlint)] Since the action delegates to `scripts/*.sh`, we also run shellcheck standalone over those files — belt-and-braces. Both passes must be strict (`--severity=style`).
- **Read-only permissions.** Lint never mutates; explicit `permissions: contents: read` avoids the default token's write scope.
- **No secrets, no environment.** This workflow must run on fork PRs without any gate.
- **Cheap.** Sub-minute runtime. Runs first, blocks self-test by virtue of branch protection.

### Workflow 2: `release-please.yml` — Release Orchestration

```yaml
name: release-please
on:
  push:
    branches: [main]
permissions:
  contents: write
  pull-requests: write
concurrency:
  group: release-please
  cancel-in-progress: false     # never cancel a partial release
jobs:
  release-please:
    runs-on: ubuntu-latest
    outputs:
      nordvpn-es-released:   ${{ steps.rp.outputs['actions/nordvpn-es--release_created'] }}
      nordvpn-es-tag:        ${{ steps.rp.outputs['actions/nordvpn-es--tag_name'] }}
      nordvpn-es-major:      ${{ steps.rp.outputs['actions/nordvpn-es--major'] }}
      # ... and the same triple for nordvpn-us, nordvpn-fr
    steps:
      - uses: googleapis/release-please-action@<sha>  # v4
        id: rp
        with:
          config-file: .github/release-please-config.json
          manifest-file: .github/release-please-manifest.json

  float-major-tag:
    needs: release-please
    runs-on: ubuntu-latest
    permissions:
      contents: write
    strategy:
      fail-fast: false
      matrix:
        include:
          - component: nordvpn-es
            released: ${{ needs.release-please.outputs.nordvpn-es-released }}
            tag:      ${{ needs.release-please.outputs.nordvpn-es-tag }}
            major:    ${{ needs.release-please.outputs.nordvpn-es-major }}
          - component: nordvpn-us
            released: ${{ needs.release-please.outputs.nordvpn-us-released }}
            tag:      ${{ needs.release-please.outputs.nordvpn-us-tag }}
            major:    ${{ needs.release-please.outputs.nordvpn-us-major }}
          - component: nordvpn-fr
            released: ${{ needs.release-please.outputs.nordvpn-fr-released }}
            tag:      ${{ needs.release-please.outputs.nordvpn-fr-tag }}
            major:    ${{ needs.release-please.outputs.nordvpn-fr-major }}
    steps:
      - if: matrix.released == 'true'
        uses: actions/checkout@<sha>
        with: { fetch-depth: 0 }
      - if: matrix.released == 'true'
        name: Move ${{ matrix.component }}-v${{ matrix.major }}
        run: |
          git config user.name  'github-actions[bot]'
          git config user.email 'github-actions[bot]@users.noreply.github.com'
          git tag -fa "${{ matrix.component }}-v${{ matrix.major }}" \
                  "${{ matrix.tag }}" \
                  -m "Update floating major tag to ${{ matrix.tag }}"
          git push origin "${{ matrix.component }}-v${{ matrix.major }}" --force
```

**Key architectural choices:**

- **Per-component outputs, not the broken `releases_created`.** Release-please v4's global `releases_created` is `true` whenever *any* package releases — [dangerous footgun](https://danwakeem.medium.com/beware-the-release-please-v4-github-action-ee71ff9de151). Use `<path>--release_created`, `<path>--tag_name`, `<path>--major` per-package outputs. The `path` is the key from `packages` in `release-please-config.json` — here, `actions/nordvpn-es` etc.
- **Matrix for tag-floating, not three copy-pasted jobs.** One job-definition, three matrix entries. Conditional `if: matrix.released == 'true'` makes no-op rounds cheap.
- **`<component>-v<MAJOR>` only, not bare `v<MAJOR>`.** A bare `v1` tag is ambiguous in a per-region monorepo: which region is v1? The source PR's convention, and release-please's default with `include-component-in-tag: true`, is `nordvpn-es-v1` / `nordvpn-es-v1.2.3`. Ship the component-prefixed floating tag only. If the repo ever houses one dominant action, revisit. For three equal regions, bare `v<MAJOR>` is wrong.
- **`--force` push with `git tag -fa`.** Floating tags are mutable by definition; this is expected. Branch protection doesn't cover tags — this is the correct place to mutate them.
- **Concurrency group without `cancel-in-progress: false`.** A second push to main while a release PR is being merged could cancel an in-flight release. Never cancel in progress.
- **Concurrency = one group for the whole file.** Release and tag-move are logically one transaction. A concurrent re-entry would try to move the same tag twice.
- **`needs: release-please` dependency is explicit.** Without it the tag-move job could race the release creation.

### Workflow 3: `self-test.yml` — Proof-of-Life

```yaml
name: self-test
on:
  push:
    branches: [main]
  pull_request:
    # Fork PRs never reach the `Preview` environment; skip-guard below.
    types: [opened, synchronize, reopened]
permissions:
  contents: read
jobs:
  skip-fork:
    runs-on: ubuntu-latest
    outputs:
      is-fork: ${{ steps.check.outputs.is-fork }}
    steps:
      - id: check
        run: |
          if [[ "${{ github.event.pull_request.head.repo.fork }}" == "true" ]]; then
            echo "is-fork=true" >> "$GITHUB_OUTPUT"
            echo "::notice::Fork PR — skipping self-test (secrets unavailable by design)"
          else
            echo "is-fork=false" >> "$GITHUB_OUTPUT"
          fi

  self-test:
    needs: skip-fork
    if: needs.skip-fork.outputs.is-fork != 'true'
    runs-on: ubuntu-latest
    environment: Preview          # scopes NORDVPN_SERVICE_USERNAME/PASSWORD
    strategy:
      fail-fast: false            # one region failing must not hide the others
      matrix:
        region: [es, us, fr]
        include:
          - { region: es, expected: ES }
          - { region: us, expected: US }
          - { region: fr, expected: FR }
    steps:
      - uses: actions/checkout@<sha>      # required — local `./actions/...` ref
      - name: Connect
        uses: ./actions/nordvpn-${{ matrix.region }}
        with:
          username: ${{ secrets.NORDVPN_SERVICE_USERNAME }}
          password: ${{ secrets.NORDVPN_SERVICE_PASSWORD }}
      - name: Assert egress
        run: |
          actual=$(curl -s https://ipinfo.io/country | tr -d '\n')
          [[ "$actual" == "${{ matrix.expected }}" ]] || { echo "egress=$actual expected=${{ matrix.expected }}"; exit 1; }
      - name: Disconnect
        if: always()
        uses: ./actions/nordvpn-${{ matrix.region }}/disconnect
```

**Key architectural choices:**

- **Local `./actions/nordvpn-<r>` path, not `uses: pau-vega/...@<ref>`.** The self-test validates the in-tree code. Using a tagged ref would test a *released* version against itself — circular and useless for catching regressions on unreleased changes. This also makes self-test independent of release-please (they can ship in any order).
- **Fork-skip guard in a dedicated job.** Fork PRs cannot see environment secrets. Explicit skip with `::notice::` tells the contributor why. Without the guard the job would run, hit a missing-secret `${{ secrets.* }}` → empty string, fail in a confusing way.
- **`environment: Preview` gates the job.** Environment-scoped secrets mean forks truly cannot touch them — belt-and-braces with the skip-guard.
- **Matrix of three regions, `fail-fast: false`.** If ES's bundled profile drifts and fails, US and FR should still prove themselves. Fast-fail would mask the working regions.
- **Disconnect always.** `if: always()` documents the consumer contract at the test site — canonical example of how to invoke.
- **Runs on `push: main` *and* on non-fork PRs.** Main catches regressions from merges; non-fork PRs catch them before merge for maintainer-authored work.

---

## Release-Please Configuration Surface

### `.github/release-please-manifest.json`

```json
{
  "actions/nordvpn-es": "0.0.0",
  "actions/nordvpn-us": "0.0.0",
  "actions/nordvpn-fr": "0.0.0"
}
```

Bootstrap values. First release per region bumps to `1.0.0` via `release-as: 1.0.0` override or via a `feat!:` commit. release-please mutates this file automatically; it is never hand-edited after bootstrap.

### `.github/release-please-config.json`

```json
{
  "release-type": "simple",
  "include-component-in-tag": true,
  "separate-pull-requests": true,
  "tag-separator": "-",
  "changelog-sections": [
    { "type": "feat",     "section": "Features"     },
    { "type": "fix",      "section": "Bug Fixes"    },
    { "type": "docs",     "section": "Documentation"},
    { "type": "chore",    "hidden": true            },
    { "type": "refactor", "section": "Code Refactoring" },
    { "type": "test",     "hidden": true            },
    { "type": "ci",       "hidden": true            }
  ],
  "packages": {
    "actions/nordvpn-es": {
      "component": "nordvpn-es",
      "package-name": "nordvpn-es"
    },
    "actions/nordvpn-us": {
      "component": "nordvpn-us",
      "package-name": "nordvpn-us"
    },
    "actions/nordvpn-fr": {
      "component": "nordvpn-fr",
      "package-name": "nordvpn-fr"
    }
  }
}
```

**Key configuration decisions:**

- **`release-type: simple`** — composite actions are not a first-class release-type; `simple` treats the package as "whatever is in this path", managed by the version in manifest. No language-specific extra-files updates (no `package.json` version field to sync).
- **`include-component-in-tag: true` + `tag-separator: "-"`** — produces tags like `nordvpn-es-v1.2.3`. `tag-separator: "@"` would produce `nordvpn-es@v1.2.3` which is also valid but less friendly to GitHub's own tag-navigation UI. Both work.
- **`separate-pull-requests: true`** — one release PR per component. A feature in `nordvpn-es` alone opens *only* an ES release PR. Without this, release-please aggregates into one PR per push — messier diffs, harder to approve partial releases.
- **`changelog-sections` override.** release-please defaults hide `fix` (hidden until v1) in some modes; explicit sections guarantee `feat`/`fix`/`docs`/`refactor` show up in each action's CHANGELOG.md, `chore`/`test`/`ci` stay hidden.
- **`packages` key is the diff path.** Commits touching files outside `packages/*` (e.g., README.md, workflows/, LICENSE) do not trigger any release PR. This is what scopes "a fix to US doesn't bump ES."

### Tag name formation → floating-major interaction

| Event | Exact tag (immutable) | Floating major tag (mutable) |
|-------|-----------------------|------------------------------|
| First ES release | `nordvpn-es-v1.0.0` | `nordvpn-es-v1` |
| ES patch | `nordvpn-es-v1.0.1` | `nordvpn-es-v1` force-moved to v1.0.1's SHA |
| ES breaking | `nordvpn-es-v2.0.0` | `nordvpn-es-v2` created at v2.0.0's SHA; `nordvpn-es-v1` stays at the last v1.x.y |
| US independent patch | `nordvpn-us-v1.0.1` | `nordvpn-us-v1` force-moved; ES tags untouched |

The floating-major job reads `steps.rp.outputs['actions/nordvpn-es--major']` to know the MAJOR for the tag it's moving. release-please exposes this output per-component in v4. [[Release-Please v4 gotchas](https://danwakeem.medium.com/beware-the-release-please-v4-github-action-ee71ff9de151)]

**Tradeoff rejected: bare `v<MAJOR>`.** Writing `v1` at the repo level (no component prefix) creates ambiguity once a second region ever has a v2 while the first is still on v1. In a three-equal-region monorepo, bare tags have no non-ambiguous semantics. Component-prefixed only.

---

## Runtime Data Flow — Consumer `uses:` Sequence

```
Consumer workflow start
│
│ step: uses: pau-vega/nordvpn-actions/actions/nordvpn-es@<ref>
│   with:
│     username: $NORDVPN_SERVICE_USERNAME
│     password: $NORDVPN_SERVICE_PASSWORD
│
▼
┌─────────────────────────────────────────────────────────────────────┐
│ GitHub Actions runner resolves ref → checks out repo @ ref          │
│ Discovers actions/nordvpn-es/action.yml                             │
└─────────────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 1 — install.sh                                                  │
│   apt-get update                                                     │
│   apt-get install -y openvpn openvpn-systemd-resolved curl jq        │
│   command -v openvpn   # fail fast if PATH missing                   │
└─────────────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 2 — connect.sh                                                  │
│   umask 077                                                          │
│   AUTH="$RUNNER_TEMP/nordvpn-auth"                                   │
│   printf '%s\n%s\n' "$USERNAME" "$PASSWORD" > "$AUTH"                │
│   chmod 0600 "$AUTH"                                                 │
│   sudo openvpn \                                                     │
│     --config actions/nordvpn-es/vpn/nordvpn-es.ovpn \                │
│     --auth-user-pass "$AUTH" \                                       │
│     --daemon \                                                       │
│     --log /var/log/openvpn.log                                       │
│                                                                      │
│   # Poll tun0 for IPv4 — bounded retry                               │
│   for i in {1..15}; do                                               │
│     if ip -4 addr show tun0 2>/dev/null | grep -q 'inet '; then      │
│       break                                                          │
│     fi                                                               │
│     [[ $i -eq 15 ]] && { echo "tun0 timeout"; tail /var/log/openvpn.log; exit 1; } │
│     sleep 2                                                          │
│   done                                                               │
└─────────────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 3 — verify-country.sh                                           │
│   EXPECTED=ES    # hardcoded per-region                              │
│   p1=$(curl -fsS --max-time 10 https://ipinfo.io/json | jq -r .country)  │
│   p2=$(curl -fsS --max-time 10 https://ifconfig.co/json | jq -r .country) │
│                                                                      │
│   if [[ "$p1" != "$EXPECTED" || "$p2" != "$EXPECTED" ]]; then        │
│     echo "::error::Country check failed: ipinfo=$p1 ifconfig.co=$p2 expected=$EXPECTED" │
│     exit 1                                                           │
│   fi                                                                 │
│                                                                      │
│   # Diagnostic outputs                                               │
│   echo "country=$EXPECTED"  >> "$GITHUB_OUTPUT"                      │
│   echo "ipinfo=$p1"         >> "$GITHUB_OUTPUT"                      │
│   echo "ifconfig=$p2"       >> "$GITHUB_OUTPUT"                      │
│   echo "ip=$(curl -fsS --max-time 10 https://ipinfo.io/ip)" >> "$GITHUB_OUTPUT" │
└─────────────────────────────────────────────────────────────────────┘
│
│ → Returns control to consumer workflow. Traffic routes via tun0.
│ → Consumer runs country-gated steps.
│
▼
┌─────────────────────────────────────────────────────────────────────┐
│ CONSUMER'S LAST STEP                                                  │
│   uses: pau-vega/nordvpn-actions/actions/nordvpn-es/disconnect@<ref> │
│   if: always()                                                       │
└─────────────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 4 — disconnect.sh (sibling sub-action, independent state)       │
│   sudo pkill -f 'openvpn.*nordvpn-es.ovpn' || true                   │
│   rm -f "$RUNNER_TEMP/nordvpn-auth" || true                          │
│   # Both guarded with || true: idempotent; orphan disconnect is OK  │
└─────────────────────────────────────────────────────────────────────┘
```

**Credential + config flow:**

1. **Secrets enter as `inputs:`** — consumer workflow injects `secrets.NORDVPN_SERVICE_USERNAME` / `..._PASSWORD` via `with:`. Action YAML exposes them as `inputs.username` / `inputs.password`, passed to `connect.sh` as `env: NORDVPN_USERNAME` / `NORDVPN_PASSWORD`.
2. **Secrets land on disk exactly once.** `connect.sh` writes `$AUTH` at `$RUNNER_TEMP/nordvpn-auth` with `umask 077` → mode 0600. OpenVPN reads it. Nothing else touches it. `disconnect.sh` removes it.
3. **Bundled `.ovpn` is read-only input.** Checked out with the repo. Never modified. Path is `actions/nordvpn-<r>/vpn/nordvpn-<r>.ovpn` (composite actions cwd is the action directory).
4. **Outputs flow only outward.** `$GITHUB_OUTPUT` writes are the sole return channel: `country`, `ip`, `ipinfo`, `ifconfig`. No secrets, no auth-file paths, no OpenVPN internals.

---

## Build Order — Dependencies Between Components

### Hard Dependencies (Must-Land-Before)

```
LICENSE + README (skeleton)
    │
    ▼
.github/workflows/actions-lint.yml
    │                                (lint is cheap gatekeeper; lands first so any
    │                                 subsequent action PR is auto-validated)
    ▼
actions/nordvpn-es/scripts/*.sh
    │                                (scripts must exist on disk before action.yml
    │                                 can reference them, or actionlint flags
    │                                 "workflow does not exist" errors)
    ▼
actions/nordvpn-es/vpn/nordvpn-es.ovpn
    │                                (bundled profile — static input)
    ▼
actions/nordvpn-es/action.yml + README.md + CHANGELOG.md (empty)
    │
    ▼
actions/nordvpn-es/disconnect/action.yml + scripts/disconnect.sh
    │                                (teardown must ship with connect;
    │                                 both referenced from consumer's workflow)
    ▼
[PORT MILESTONE — ES is functional locally]
    │
    ▼
actions/nordvpn-us/**  and  actions/nordvpn-fr/**    (parallel, mirror of -es)
    │                                (US and FR are copy-shape from ES. They
    │                                 should ship in ONE PR each or as one
    │                                 feat(nordvpn-us):/ feat(nordvpn-fr):
    │                                 branch to keep release-please history
    │                                 per-region-clean.)
    ▼
.github/workflows/self-test.yml
    │                                (self-test uses ./actions/nordvpn-<r>
    │                                 local refs, so it only needs the actions
    │                                 to EXIST in tree; no tag needed)
    ▼
[SELF-TEST MILESTONE — real end-to-end verified]
    │
    ▼
.github/release-please-config.json + release-please-manifest.json
.github/workflows/release-please.yml
    │                                (release tooling is LAST because:
    │                                  1. it operates on existing paths
    │                                  2. testing it requires changes to merge
    │                                  3. landing it early means bootstrapping
    │                                     empty CHANGELOGs that have to be
    │                                     reset before the first real release)
    ▼
.github/CODEOWNERS + dependabot.yml + AGENTS.md
    │                                (metadata + contributor UX — polish last)
    ▼
[v1 RELEASE MILESTONE]
    │
    ▼
Branch protection rules on main:
  - actions-lint required
  - self-test required (non-fork PRs only — implicit)
```

### Soft Dependencies / Ordering Notes

- **ES before US/FR is strict** — the port establishes the contract (inputs, outputs, script file names, action.yml shape). US and FR are literal copies of that contract with different `.ovpn` + hardcoded `EXPECTED=US/FR`. Doing them in parallel with the port multiplies review burden and risks divergent contracts.
- **`actions-lint` before everything else is strong, not absolute** — you *could* write action.yml + scripts first and wire lint at the end. Doing lint first means every PR from the port-ES step forward gets caught on mistakes for free. The cost of doing lint first is ~30 min of workflow writing; the benefit compounds.
- **`release-please.yml` after `self-test.yml` is strong** — release-please is metadata. Self-test exercises the code. If you land release-please first, you can't test that it works end-to-end until something is mergeable-to-release, which means writing throwaway `feat(nordvpn-es):` commits to validate the pipeline. Much easier to finish the code, then bolt on release tooling knowing what it has to release.
- **Self-test independent of release-please** — documented explicitly because it *is* independent: self-test uses `./actions/nordvpn-<r>` local paths, not tagged references. The two systems never touch each other's outputs. This means if release-please setup drags, self-test can still be green on main.

### Branch Protection Implications

Once the above is in place, branch protection on `main` should require:

1. **`actions-lint` status** — always. Cheap, runs on every PR touching actions or workflows.
2. **`self-test` status** — required on non-fork PRs; skipped gracefully on fork PRs (the skip-guard job returns green). GitHub's required-status-check mechanism treats a skipped-with-success job as passing, so fork PRs aren't blocked by the check they can't satisfy.
3. **CODEOWNERS review** — `@pau-vega` on `/actions/**` means any action change needs maintainer approval.
4. **No direct push to main** — release-please PRs and normal feature PRs both go through review.
5. **Signed commits not required for v1** — adds friction without clear threat-model benefit for a public-repo portfolio project.

---

## Architectural Patterns

### Pattern 1: Sibling Sub-Action for Teardown

**What:** Ship a sub-action at `actions/<name>/<teardown>/` (here: `actions/nordvpn-<r>/disconnect/`) whose sole job is post-hoc cleanup. Consumer invokes it as a separate step with `if: always()`.

**When to use:** Any composite action that allocates runner-level resources (VPN, mounted volumes, background daemons, temp credentials) that must be released whether the main step succeeds or fails.

**Trade-offs:**
- Pro: Respects the composite-no-`post:` constraint without falling back to JS/Docker.
- Pro: Zero state sharing — disconnect works even if connect partially failed.
- Pro: Explicit in the consumer's workflow — "I see the teardown step."
- Con: Consumer must remember to add the step, and add `if: always()`. Documentation burden.
- Con: Two `uses:` lines per region instead of one. Marginally verbose.

**Example:**

```yaml
- uses: pau-vega/nordvpn-actions/actions/nordvpn-es@v1
  with: { username: ${{ secrets.NV_USER }}, password: ${{ secrets.NV_PASS }} }
- run: ./country-gated-work.sh
- uses: pau-vega/nordvpn-actions/actions/nordvpn-es/disconnect@v1
  if: always()
```

### Pattern 2: Bundled Config Per-Region Sibling

**What:** Each region is a fully self-contained directory (`action.yml`, `scripts/`, `vpn/`, `disconnect/`). Duplicate scripts across regions are acceptable at N=3; the deduplication cost exceeds the maintenance cost.

**When to use:** Small-N multi-variant actions (2-5 variants) where variants differ only by bundled content and a single hardcoded constant.

**Trade-offs:**
- Pro: Clean `uses:` path; every pin covers every file the action needs.
- Pro: Release-please config is N-package simple.
- Pro: Independent version evolution per region.
- Con: Fix a script bug → three commits (or one commit touching three paths, which release-please handles correctly).
- Con: Drift risk: ES gets a fix, US and FR don't. Mitigated by disciplined fanout or CI check.

**Example:** `actions/nordvpn-es/scripts/connect.sh` and `actions/nordvpn-us/scripts/connect.sh` are byte-identical except for their comment header. Three files, one logical script.

### Pattern 3: Local-Path Self-Test (Decoupled from Release)

**What:** Self-test workflow uses `uses: ./actions/nordvpn-<r>` (local path), not `uses: pau-vega/nordvpn-actions/actions/nordvpn-<r>@<ref>` (published ref).

**When to use:** Any monorepo that wants to validate unreleased code end-to-end before it's tagged.

**Trade-offs:**
- Pro: Self-test and release-please are independent; either can ship without the other.
- Pro: Tests the tree as-is, not a pre-tagged snapshot.
- Pro: Fast iteration — no tag needed to see if a fix works in CI.
- Con: `./actions/...` only works when the workflow runs in-repo, which is fine since self-test only ever runs in this repo.
- Con: Doesn't catch "did the release tag get published correctly?" — but that's release-please's job, not self-test's.

**Example:**

```yaml
- uses: actions/checkout@<sha>
- uses: ./actions/nordvpn-es    # local; evaluated at PR-HEAD SHA
```

### Pattern 4: Per-Component Release-Please Output Routing

**What:** Read `steps.rp.outputs['actions/nordvpn-es--release_created']` rather than the global `releases_created`. Every downstream conditional key is path-prefixed.

**When to use:** Any release-please v4 monorepo with >1 component.

**Trade-offs:**
- Pro: Correctness — the global `releases_created` is [true when *any* component releases](https://danwakeem.medium.com/beware-the-release-please-v4-github-action-ee71ff9de151), which is a footgun.
- Pro: Enables per-component downstream jobs (e.g., move only ES's floating tag, not US's).
- Con: Verbose output names; easy typo target.
- Con: The path in the output key must exactly match the package key in `release-please-config.json`. Drift silently breaks conditionals.

**Example:** The floating-major matrix job uses `needs.release-please.outputs.nordvpn-es-tag` (sanitized output name) sourced from `steps.rp.outputs['actions/nordvpn-es--tag_name']`. One-step of sanitization at the workflow-output boundary so downstream steps aren't quoting string keys.

---

## Anti-Patterns

### Anti-Pattern 1: Shared `_shared/scripts/` at N=3

**What people do:** Extract common `connect.sh` / `verify-country.sh` to `actions/_shared/scripts/` on first encounter of duplicated code, to "DRY" the codebase.

**Why it's wrong:**
- `_shared` isn't a released package — it has no version, no changelog, no semver contract. A change there silently affects every region pinned at any version.
- release-please has to either add `_shared` as a no-op package (messy) or exclude it from diff detection (breaks changelog fidelity).
- The `uses:` path pin no longer reflects all the code the action runs — unless the consumer pins by SHA.
- Three files is not enough duplication to earn the abstraction cost. The source PR works without it.

**Do this instead:** Triplicate. At N=5 or on the first cross-region bug, extract. Flag post-v1.

### Anti-Pattern 2: Bare `v<MAJOR>` Floating Tag in a Multi-Region Monorepo

**What people do:** Create both `nordvpn-es-v1` and bare `v1` tags for "convenience," reasoning the consumer can pick.

**Why it's wrong:**
- Bare `v1` is a repo-level tag. When ES ships v2 (`nordvpn-es-v2.0.0`) while US is still on v1.0.1, what does bare `v1` point to? If it points to ES's last v1, then `uses: pau-vega/nordvpn-actions/actions/nordvpn-us@v1` silently resolves to a SHA where US's files *also* existed but are now stale.
- Tags resolve at the *repo* level — `uses:` chooses a SHA, then walks into the `actions/<r>/` subpath at that SHA.
- Creates a footgun: the repo's three regions drift independently, but a bare `v1` tag says "everything's at v1" which is a claim no single SHA can honestly make.

**Do this instead:** `<component>-v<MAJOR>` only. Document the per-region tag format in README. If consumers want a "universal" pin, they pin by SHA (recommended anyway for security-critical workflows).

### Anti-Pattern 3: `post:` Polyfill via Mid-Workflow Hidden Cleanup

**What people do:** Inside the composite action's `runs.steps`, add a final cleanup step with `if: always()` intending it to be a teardown.

**Why it's wrong:**
- [`if:` on composite `run` steps is unsupported in the way it works in workflow-level steps](https://github.com/orgs/community/discussions/26743). Even if the syntax is accepted, the step runs inline inside the composite's linear execution, not *after* the workflow's subsequent steps. If a later consumer step fails, the cleanup has already run (successfully), then the workflow fails with a leaked state from the consumer's step.
- It's a mental-model mismatch: consumers expect teardown to be failure-tolerant across subsequent steps. Inline cleanup is not.

**Do this instead:** Sibling sub-action invoked separately by the consumer with `if: always()`. See Pattern 1.

### Anti-Pattern 4: `releases_created` in Multi-Component Release-Please v4

**What people do:** Gate downstream jobs on `if: steps.release.outputs.releases_created == 'true'`.

**Why it's wrong:**
- [`releases_created` is `true` regardless of which component released](https://danwakeem.medium.com/beware-the-release-please-v4-github-action-ee71ff9de151). An ES-only release triggers US and FR post-release jobs.
- Silently ships wrong tags, wrong deploys, wrong notifications.

**Do this instead:** `steps.release.outputs['<package-path>--release_created']` per component. The double-dash separator is intentional, matching release-please's internal naming.

### Anti-Pattern 5: Runtime `.ovpn` Fetch from NordVPN API

**What people do:** Call NordVPN's server-recommendation API at runtime to fetch a "fresh" `.ovpn`, reasoning "then we don't have stale configs."

**Why it's wrong:**
- Adds a network dependency to *every* `uses:` invocation — another failure mode before the VPN even starts.
- Rate-limited. CI runs get 429'd.
- Not reproducible — same pin, different SHA, different actual server behavior on different days.
- Scope creep: now the action has two sources of truth (API + bundled).

**Do this instead:** Bundle one `.ovpn` per region. Accept drift. Refresh as a maintenance task tracked in issues. See PROJECT.md Out-of-Scope.

---

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| NordVPN (OpenVPN endpoint) | `openvpn --daemon` against bundled `.ovpn` + service credentials | Service credentials only; account credentials fail auth. |
| `ipinfo.io` | `curl -fsS --max-time 10 https://ipinfo.io/json \| jq -r .country` | First of two geo providers. |
| `ifconfig.co` | `curl -fsS --max-time 10 https://ifconfig.co/json \| jq -r .country` | Second of two — both must agree. |
| GitHub Actions runner (`ubuntu-latest`) | `apt-get`, `sudo`, `ip`, `curl`, `jq`, `openvpn` | Ubuntu-only; no macOS/Windows support. |
| `release-please-action@v4` | Invoked from `release-please.yml`; reads manifest, opens release PR | Pinned by SHA with `# v4.x.y` comment. |
| `rhysd/actionlint` | Downloaded via curl in `actions-lint.yml`; embeds `shellcheck` | Pinned by version tag in the download script. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Consumer workflow ↔ `nordvpn-<r>` action.yml | `with: { username, password }` → composite `inputs.*` → scripts' env vars | One-way inward; outputs emerge via `$GITHUB_OUTPUT`. |
| `action.yml` ↔ `scripts/*.sh` | `shell: bash`, `run: ./scripts/<name>.sh`, env vars set in YAML | No runtime coupling beyond env. Scripts are independently shellcheck-able. |
| `connect.sh` ↔ `disconnect.sh` | **None** — file-system only (`$RUNNER_TEMP/nordvpn-auth`), OS process table (`pgrep openvpn`) | Intentional decoupling. Disconnect works without connect having succeeded. |
| `actions/nordvpn-<r>/` ↔ `actions/nordvpn-<r>/disconnect/` | Filesystem sibling; consumer invokes both separately | Two independent `uses:` refs. |
| `release-please-action` ↔ `.github/release-please-*.json` | JSON files are the contract | Manifest is mutated by the action; config is mutated only by humans. |
| `release-please` job ↔ `float-major-tag` job | `needs:` + `outputs` | Strict dependency; tag-move only runs on successful release. |

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 3 regions (v1) | Current shape. Duplicate scripts, per-region `.ovpn`, per-component release-please. |
| 5-7 regions | Still current shape. Triplication becomes septuplication but still under the DRY-cost threshold. |
| 8-10 regions | Extract `actions/_shared/scripts/` with a versioned contract. Add a `scripts-lint` check to ensure shared scripts shellcheck clean independently. Consider a region-generator script that stamps out a new region directory from a template. |
| 10+ regions | Reconsider fundamentals: is this a composite-action problem, or is it a Docker/JS action that accepts `region:` as an input + bundles all profiles? At 10+ regions, the N-copies strategy becomes a release-please config stress test. |

### First Bottleneck: Bundled Profile Staleness

What breaks first is not scale — it's drift. NordVPN rotates servers; a bundled `.ovpn` fails connection after months. Self-test catches this (daily cron if we added it; today, only on PR/main pushes). Mitigation: periodic refresh milestone, documented as a maintenance task, not automated in v1.

### Second Bottleneck: Release Serialization

release-please opens *one* release PR per component. At 3 components, that's 3 PRs max per merge. At 20 components, the PR-opening cost is noticeable and review burden grows. Mitigation: `separate-pull-requests: false` (aggregate into one PR) becomes more attractive at 10+ components.

---

## Real-World Exemplars Cited

| Exemplar | Relevance | Specific Observation |
|----------|-----------|----------------------|
| [`github/codeql-action`](https://github.com/github/codeql-action) | Multi-action monorepo (JS, not composite) | Sub-actions at repo root (`init/`, `analyze/`, `upload-sarif/`) each with own `action.yml`; scripts live at `lib/*.js` (sibling, root-level, shared). Confirmed via `init/action.yml` references `../lib/init-action.js`. |
| [`loozhengyuan/actions`](https://github.com/loozhengyuan/actions) | Multi-action composite monorepo | Actions at repo root (`setup-hugo/`, `setup-kicad/`, etc.); `.github/workflows/setup-hugo.yml` triggers on push/PR to main and uses local `./setup-hugo` for self-test. Confirms local-path self-test pattern. |
| [`MitaWinata/monorepo_independent_releases`](https://github.com/MitaWinata/monorepo_independent_releases) | release-please monorepo (non-action, but config is applicable) | `release-please-config.json` + `.release-please-manifest.json` at repo root; `packages` keyed by `model/a`, `model/b`; release workflow reads `<path>--release_created` + `<path>--tag_name` per-package outputs. Exact config shape we adopt. |
| [`amarjanica/release-please-monorepo-example`](https://github.com/amarjanica/release-please-monorepo-example) | Canonical release-please monorepo template | Confirms `.release-please-manifest.json` + `release-please-config.json` at repo root; `packages` object maps paths to release types; each package (`hello-react/`, `hello-rust/`) is fully self-contained. Referenced in PROJECT.md Context as known good template. |
| [`google-github-actions/*`](https://github.com/google-github-actions) | Single-action-per-repo counter-example | Every action is its own repo (`auth`, `setup-gcloud`, `deploy-cloudrun`). Demonstrates the alternative we rejected. Argues against monorepo at Google's scale where each action has its own maintainer team. |
| [`tailscale/github-action`](https://github.com/tailscale/github-action) | VPN action — but JS, not composite | Uses ephemeral-node pattern instead of explicit teardown. Argues *for* our sibling-disconnect approach: if composite were the goal, sibling is the only clean option; if not, JS + `post:` is the canonical path. Composite-only per PROJECT.md constraints forces our hand. |
| [Community Discussion #26743](https://github.com/orgs/community/discussions/26743) | Official GitHub response on composite no-`post:` | GitHub confirms composite actions don't support `pre:` / `post:`. Source of our architectural constraint. |
| [Community Discussion #141741](https://github.com/orgs/community/discussions/141741) | How to version multiple actions in one repo | Recommends `action-name/vX` hierarchical tag format. Matches our `<component>-v<MAJOR>` decision. |
| [Release-Please v4 gotchas (Medium)](https://danwakeem.medium.com/beware-the-release-please-v4-github-action-ee71ff9de151) | v4 output semantics | Documents the `releases_created` footgun and the `<path>--release_created` safe pattern. Non-official but widely cited. |
| [cicirello's major-tag gist](https://gist.github.com/cicirello/ade1d559a89104140557389365154bc1) | Floating major tag recipe | Canonical `git tag -fa "${MAJOR}" -m 'Update major version tag'; git push origin "${MAJOR}" --force` pattern. Adapted for component-prefixed tags in our release-please workflow. |
| [Tutellus/tutellus-frontend-utils PR #159](https://github.com/Tutellus/tutellus-frontend-utils/pull/159) | Direct source of the ES action | Reference implementation with `actions/nordvpn-es/{action.yml, disconnect/action.yml, scripts/*.sh, vpn/nordvpn-es.ovpn, README.md}`. Every file path and contract we preserve. |

---

## Sources

- [google-github-actions org](https://github.com/google-github-actions) — confirms one-repo-per-action for high-profile actions
- [loozhengyuan/actions](https://github.com/loozhengyuan/actions) — multi-action composite monorepo at repo root
- [github/codeql-action](https://github.com/github/codeql-action) — multi-action JS monorepo at repo root
- [MitaWinata/monorepo_independent_releases](https://github.com/MitaWinata/monorepo_independent_releases) — release-please monorepo workflow reference
- [amarjanica/release-please-monorepo-example](https://github.com/amarjanica/release-please-monorepo-example) — canonical release-please template
- [release-please manifest releaser docs](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md) — `packages` map, component, tag format options
- [release-please-action v4](https://github.com/googleapis/release-please-action) — action wrapper, monorepo outputs, floating major tag example
- [Community Discussion #26743](https://github.com/orgs/community/discussions/26743) — composite actions no-`post:` confirmed by GitHub
- [Community Discussion #141741](https://github.com/orgs/community/discussions/141741) — multi-action versioning, hierarchical tag format
- [Community Discussion #41927](https://github.com/orgs/community/discussions/41927) — sibling composite action limitations
- [Community Discussion #24990](https://github.com/orgs/community/discussions/24990) — multi-action-monorepo possibility (codeql-action cited)
- [Community Discussion #46648](https://github.com/orgs/community/discussions/46648) — composite cleanup patterns (Tailscale VPN case, no canonical answer)
- [actions/runner#1478](https://github.com/actions/runner/issues/1478) — open feature request for composite `post:` support
- [rhysd/actionlint](https://github.com/rhysd/actionlint) — static checker, shellcheck integration
- [Release-please v4 gotchas](https://danwakeem.medium.com/beware-the-release-please-v4-github-action-ee71ff9de151) — `releases_created` footgun
- [amarjanica.com: Automate GitHub Releases with Release Please](https://www.amarjanica.com/automate-github-releases-with-release-please/) — `include-component-in-tag`, `tag-separator` examples
- [cicirello major-tag automation gist](https://gist.github.com/cicirello/ade1d559a89104140557389365154bc1) — floating major tag force-move recipe
- [dev.to: Automate Updating Major Release Tag](https://dev.to/cicirello/automate-updating-major-release-tag-on-new-releases-of-a-github-action-cci) — floating tag rationale
- [GitHub Docs: Creating a composite action](https://docs.github.com/en/actions/sharing-automations/creating-actions/creating-a-composite-action) — composite action reference
- [Tutellus PR #159](https://github.com/Tutellus/tutellus-frontend-utils/pull/159) — source implementation of `nordvpn-es`

---

*Architecture research for: multi-action GitHub Actions monorepo (composite, per-region NordVPN egress)*
*Researched: 2026-04-24*
