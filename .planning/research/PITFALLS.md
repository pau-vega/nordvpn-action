# Pitfalls Research

**Domain:** Composite GitHub Actions monorepo for NordVPN country-egress, with release-please releases, floating major tag automation, and self-test that consumes real credentials
**Researched:** 2026-04-24
**Confidence:** HIGH (most items cross-referenced against GitHub Security Lab, OpenVPN community tickets, googleapis/release-please issues, and known CVE-class advisories; LOW items flagged inline)

This file catalogs the specific mistakes repos of this shape make. Every entry is distinctive to at least one of: composite-action mechanics, monorepo release plumbing, VPN/OpenVPN runner specifics, or self-test with production secrets. Generic advice ("write tests," "review PRs") is out of scope.

## Critical Pitfalls

### Pitfall 1: Teardown in the composite instead of a sibling `disconnect/` action

**What goes wrong:**
Composite actions do not support `post:` or `post-if:` steps — those fields exist only for JavaScript and Docker actions ([community discussion #26743](https://github.com/orgs/community/discussions/26743), [runner issue #1478](https://github.com/actions/runner/issues/1478)). If the repo tries to fold "disconnect + clear auth file" into the same `action.yml` as "connect," the teardown only runs on success. A failed `verify-country` step leaves `openvpn` still running, `tun0` still attached, and `auth.txt` still on disk. On shared/self-hosted runners this leaks into subsequent jobs; even on ephemeral runners it corrupts the logs and can mask the real failure.

**Why it happens:**
Node-action muscle memory — authors assume `post:` works everywhere. The YAML grammar silently accepts unknown keys on some runner versions, so the file validates but the cleanup never fires.

**How to avoid:**
Ship `actions/nordvpn-<region>/disconnect/action.yml` as a separate composite sub-action from day one. Document in every README that the caller MUST invoke it with `if: always()`. Include a copy-paste Usage block showing both `uses:` lines. Lint-check the README block with a CI test that extracts the YAML snippet and runs `actionlint` on it.

**Warning signs:**
- `action.yml` contains a step named "cleanup" or "disconnect" at the bottom
- The Usage example in the README only has one `uses:` line
- Self-test job doesn't show a separate "Disconnect VPN" step in the logs

**Phase to address:**
Phase 1 (Port nordvpn-es). Teardown-as-sibling must be baked into the initial port; changing it later breaks consumer workflows.

---

### Pitfall 2: `pull_request_target` with checkout of PR code — arbitrary code execution + secret exfiltration

**What goes wrong:**
`pull_request_target` runs the workflow from the base ref with full access to `secrets.*` and a read/write `GITHUB_TOKEN` ([GitHub Security Lab: Preventing pwn requests](https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/)). If the workflow then does `actions/checkout@v4` with `ref: ${{ github.event.pull_request.head.sha }}`, it runs attacker-controlled code with the production `NORDVPN_SERVICE_USERNAME` / `NORDVPN_SERVICE_PASSWORD` in scope. The attacker doesn't need a code-injection bug — a `preinstall` hook in a modified `package.json`, a modified `scripts/connect.sh`, or a new `.github/workflows/*.yml` is enough. Real advisories: [timescale/pgai GHSA-89qq-hgvp-x37m](https://github.com/timescale/pgai/security/advisories/GHSA-89qq-hgvp-x37m), [spotipy-dev GHSA-h25v-8c87-rvm8](https://github.com/spotipy-dev/spotipy/security/advisories/GHSA-h25v-8c87-rvm8). In 2026, automated attackers ([hackerbot-claw campaign, April 2026](https://unit42.paloaltonetworks.com/github-actions-supply-chain-attack/)) actively scan public repos for this exact misconfiguration and submit PRs at scale — 475+ malicious PRs in a 26-hour window.

**Why it happens:**
`pull_request` from forks can't reach secrets. Tempted to "just use `pull_request_target` to run the self-test on fork PRs." Every advisory cited above started as that exact rationalization.

**How to avoid:**
- Self-test trigger is `pull_request` (not `pull_request_target`). Fork PRs cannot reach `environment: Preview` secrets; they must skip cleanly with a clear message.
- Guard the VPN-dependent step with `if: vars.NORDVPN_SERVICE_USERNAME != '' && github.event.pull_request.head.repo.full_name == github.repository` so fork PRs exit green with "VPN self-test skipped (fork)."
- Document in `AGENTS.md` and the root README that this is deliberate, not a bug.
- NEVER add `pull_request_target` to any workflow in this repo, period. If a future need arises, use the split-workflow pattern (unprivileged `pull_request` + privileged `workflow_run`) with artifact handoff.
- Set the workflow-level `permissions:` block to `contents: read` and nothing else; only escalate on specific jobs that need more.

**Warning signs:**
- Grep for `pull_request_target` in `.github/workflows/` — must return zero hits
- Fork PRs fail instead of skipping with a clear message
- Workflow lacks a top-level `permissions:` block
- `checkout` in a self-test job references `head.sha` or `head.ref` without a repo-ownership guard

**Phase to address:**
Phase 2 (Self-test workflow). This must be right on day one of the self-test job existing — retrofitting security is never as good as not introducing the hole.

---

### Pitfall 3: DNS leak via missing `openvpn-systemd-resolved` — traffic goes over VPN but DNS queries don't

**What goes wrong:**
Install `openvpn` without `openvpn-systemd-resolved`. The tunnel comes up, `tun0` gets an IPv4, `curl ifconfig.co` returns the expected country IP — green check. But applications that resolve hostnames use `systemd-resolved` on Ubuntu 22.04/24.04 runners, which still queries the runner's original DNS servers unless the OpenVPN `up/down` script actively reconfigures it via DBus ([systemd/systemd#7182](https://github.com/systemd/systemd/issues/7182), [jonathanio/update-systemd-resolved](https://github.com/jonathanio/update-systemd-resolved)). Net effect: the geo-IP verify passes, but the app being tested leaks its hostname lookups to the runner's default resolver. Downstream: "the test ran from Spain" is false — lookups went through GitHub's infrastructure, not the Spanish exit. Silent correctness bug with a green CI badge.

**Why it happens:**
The geo-IP provider check only sees egress; it can't see that DNS escaped a different interface. Authors believe "VPN up + correct IP = done."

**How to avoid:**
- Install `openvpn-systemd-resolved` alongside `openvpn` in `scripts/install.sh`. Non-negotiable.
- The `.ovpn` must include `script-security 2`, `up /etc/openvpn/update-systemd-resolved`, `down /etc/openvpn/update-systemd-resolved`, `down-pre`, and the `DOMAIN-ROUTE .` pull override (`dhcp-option DOMAIN-ROUTE .`) so systemd-resolved routes the full DNS namespace through the VPN resolvers.
- In `verify-country.sh`, add a DNS-egress check after the IP check: `dig +short @127.0.0.53 whoami.cloudflare` or equivalent, and assert the response matches the expected region. Two different signals = two different failure modes caught.
- Document the DNS contract in the README: "This action routes both IPv4 egress and DNS through the exit node."

**Warning signs:**
- `scripts/install.sh` installs `openvpn` but not `openvpn-systemd-resolved`
- `.ovpn` lacks `script-security 2` or `DOMAIN-ROUTE`
- `verify-country.sh` only checks HTTP IP, no DNS assertion
- `resolvectl status` in the logs shows DNS servers on `eth0` still active for `~.` (the catch-all)

**Phase to address:**
Phase 1 (Port nordvpn-es) — verify the source PR #159 already does this correctly, and if not, fix it in the port. Phase 3 (US/FR regions) inherits the fix via shared helpers.

---

### Pitfall 4: Scripts referenced by relative path instead of `${{ github.action_path }}`

**What goes wrong:**
`action.yml` has `run: ./scripts/connect.sh`. Works when developing locally from repo root. Breaks the instant a caller's workflow has a different CWD, because composite actions inherit the job's working directory, not the action's ([runner issue #1348](https://github.com/actions/runner/issues/1348), [GitHub Docs: Creating a composite action](https://docs.github.com/actions/creating-actions/creating-a-composite-action)). Caller sees `./scripts/connect.sh: No such file or directory` and can't figure out why — their repo doesn't have a `scripts/` directory.

**Why it happens:**
`github.action_path` is not intuitive. Developers test locally where paths happen to line up.

**How to avoke:**
Every `run:` step that invokes a script must use either `${{ github.action_path }}/scripts/connect.sh` or `$GITHUB_ACTION_PATH/scripts/connect.sh`. Set the scripts executable bit at repo level (`git update-index --chmod=+x`) so `chmod +x` is not needed at runtime. Add a shellcheck CI rule that flags `./scripts/` inside `action.yml`.

**Warning signs:**
- `grep -n "\./scripts" actions/**/action.yml` returns matches
- Scripts are not executable in git (`git ls-files -s actions/**/*.sh | grep -v 100755`)
- Caller workflow at a consumer repo fails with "No such file or directory" on first run

**Phase to address:**
Phase 1 (Port nordvpn-es) and enforced in Phase 0 lint via `actionlint`.

---

### Pitfall 5: Auth file persisted under `$GITHUB_WORKSPACE` with wider-than-0600 permissions

**What goes wrong:**
`auth.txt` written to `./auth.txt` (i.e., `$GITHUB_WORKSPACE/auth.txt`) at default mode 0644. Two failure modes: (1) `actions/checkout` on a subsequent job can reset the workspace back to the default branch, leaving the auth file either in place from a prior run or gone unexpectedly mid-execution; (2) 0644 means any tool running in the same job as a non-root user on self-hosted can read the service credentials. `$RUNNER_TEMP` is the runner-scoped temp dir that gets cleared between jobs on hosted runners and is conventionally private.

**Why it happens:**
`pwd` is muscle-memory. Hard to remember that `RUNNER_TEMP` is the right scope for transient secrets.

**How to avoid:**
- Always write auth to `${RUNNER_TEMP}/nordvpn-<region>-auth.txt`.
- `install -m 0600 /dev/null "$AUTH_FILE"` before any writes, then `printf '%s\n%s\n' "$user" "$pass" > "$AUTH_FILE"`. Never `echo "$user\n$pass" > ...` because `echo` interprets escapes inconsistently across shells.
- `disconnect/scripts/disconnect.sh` always runs `shred -u` (or `rm -f` with mode verification) on the auth file, whether openvpn was running or not.
- Shellcheck-enforce: any reference to `auth.txt` or `$AUTH_FILE` must be path-prefixed with `$RUNNER_TEMP`.

**Warning signs:**
- `auth.txt` appears in the root of the workspace in a job log
- `ls -la` in logs shows anything other than `-rw-------` for the auth file
- Disconnect script only runs `rm` conditionally on the tunnel being up

**Phase to address:**
Phase 1 (Port) must follow this from the source PR #159 — verify and harden if source doesn't.

---

### Pitfall 6: Credentials leaked via `set -x` on error or step outputs

**What goes wrong:**
Two related mistakes:
1. Enabling `set -x` (shell trace) during debugging or hitting `set -euxo pipefail` early, then calling `openvpn --auth-user-pass <file>` or similar — bash prints the expanded command line including any var substitution. GitHub's log masking catches values passed via `secrets.*` context inputs, but not values read from a file, not values in arrays, and notoriously not values that round-trip through a subshell ([community #25225](https://github.com/orgs/community/discussions/25225), [actions/runner #1557](https://github.com/actions/runner/issues/1557)).
2. Setting a step `output:` from a value derived from a secret — outputs bypass the masking heuristics ([community #37942](https://github.com/orgs/community/discussions/37942)). Once printed to the output log, the value is in the logs forever (can only be redacted by deleting the run).

**Why it happens:**
`set -x` is the default debug toggle. Step outputs feel safe because input secrets are masked.

**How to avoid:**
- Scripts use `set -euo pipefail` — not `set -euxo pipefail`. No trace mode in shipped scripts.
- If a script must print diagnostic info, redirect sensitive command lines: `openvpn --auth-user-pass "$AUTH_FILE" >/tmp/openvpn.log 2>&1 || { tail -n 50 /tmp/openvpn.log; exit 1; }` — and run `sed -i 's|\(user=\)[^&]*|\1REDACTED|g'` on the log before printing.
- `action.yml` outputs are never derived from secrets. Only safe values (exit IP, country code, tunnel interface name) can be outputs.
- Mask any non-secret value that resembles a credential format: `echo "::add-mask::$derived_value"` before first use.
- shellcheck rule: flag any `set -x` or `bash -x` in scripts under `actions/`.

**Warning signs:**
- Job logs contain a line beginning with `+ openvpn` (shell trace marker)
- `set -x` appears anywhere in `scripts/`
- `outputs:` block in `action.yml` references a variable whose value comes from a secret input
- `echo "$NORDVPN_SERVICE_PASSWORD"` (even indirectly via `ps`, `systemctl status`, `journalctl` dumps) appears in a debugging step

**Phase to address:**
Phase 0 (Lint + CI skeleton) — shellcheck and actionlint block this class at PR time.

---

### Pitfall 7: Using archived `google-github-actions/release-please-action` instead of canonical `googleapis/release-please-action`

**What goes wrong:**
Copy-paste an old example that references `google-github-actions/release-please-action@v3` or `@v4`. The repo was archived in August 2024 and moved to `googleapis/release-please-action` ([googleapis/release-please issue #2288](https://github.com/googleapis/release-please/issues/2288), [google-github-actions/release-please-action README](https://github.com/google-github-actions/release-please-action)). GitHub does NOT follow redirects for `uses:` references — the workflow still runs, pulls the last archived version (frozen behavior, no bug fixes, no new config keys), silently misbehaves on monorepo features released after the archive date.

**Why it happens:**
Old blog posts, old READMEs, old LLM training data. The archived repo still "works" in the sense that the action resolves and runs.

**How to avoid:**
- Use `googleapis/release-please-action@<SHA> # v4.x.x` form in the release workflow.
- Dependabot config watches `.github/workflows/` so the action line stays current.
- Add a CI check that greps for `google-github-actions/release-please-action` and fails if found.

**Warning signs:**
- Any hit for `google-github-actions/release-please-action` anywhere in `.github/`
- release-please PR bodies missing features that the current docs advertise (component-aware changelog entries, `include-component-in-tag` support)

**Phase to address:**
Phase 4 (release-please wiring). Very easy to get wrong once because of stale examples; enforce with lint.

---

### Pitfall 8: Wrong `release-type` for an action repo (`node`/`generic` vs `simple`)

**What goes wrong:**
Action repos have no `package.json`, no `setup.py`, no `go.mod` — just `action.yml` and shell scripts. If `release-type: node` is set, release-please looks for `package.json` to bump, fails to find it, and either errors or silently skips the version update. `release-type: generic` requires a `version.txt` file you must maintain. `release-type: simple` is the right choice: release-please manages the version in `.release-please-manifest.json` only, and no source file is touched ([release-please manifest-releaser docs](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md)).

**Why it happens:**
Defaults. `node` is the most common blog-post example. Authors don't realize action repos are their own category.

**How to avoid:**
`release-please-config.json` uses `"release-type": "simple"` for every package under `actions/nordvpn-<region>`. No exceptions. Same for each `disconnect/` sub-action if separately released (we ship one release per region, not per sub-action, so only the parent package is listed).

**Warning signs:**
- First release-please PR mentions editing a `package.json` or `version.txt`
- CHANGELOG.md gets created but the release-please PR title has "Release 0.0.0" or doesn't bump at all
- Manifest file content is stable across merges despite new commits

**Phase to address:**
Phase 4 (release-please wiring).

---

### Pitfall 9: Missing per-package path filters — commits in one region bump all regions

**What goes wrong:**
Single `packages: {}` block with paths `.` or missing. release-please sees a `feat(nordvpn-es):` commit and bumps every package in the manifest because it can't scope commits to paths. CHANGELOG pollution across regions; consumer who pinned `nordvpn-us-v1.0.3` gets an auto-bump to `v1.0.4` with no actual US change.

**Why it happens:**
Copy-paste monorepo examples that have one package. New authors don't realize the scoping is per-path, not per-conventional-commit-scope.

**How to avoid:**
```json
{
  "packages": {
    "actions/nordvpn-es": {
      "release-type": "simple",
      "component": "nordvpn-es",
      "include-component-in-tag": true
    },
    "actions/nordvpn-us": { "release-type": "simple", "component": "nordvpn-us", "include-component-in-tag": true },
    "actions/nordvpn-fr": { "release-type": "simple", "component": "nordvpn-fr", "include-component-in-tag": true }
  }
}
```
Each package's path is the object key; release-please only considers commits that touch files under that path. Shared helpers (if any) go under `actions/_shared/` which is NOT a release-please package — or get duplicated across region packages until a shared release is genuinely needed.

**Warning signs:**
- release-please opens a PR titled `chore: release nordvpn-es 1.0.4, nordvpn-us 1.0.4, nordvpn-fr 1.0.4` when only `nordvpn-es/` has commits
- Three changelogs update on a single-region commit
- `paths_released` JSON output lists all three paths

**Phase to address:**
Phase 4 (release-please wiring). Catch via the first dry-run PR — if it bundles regions, the config is wrong.

---

### Pitfall 10: Tag namespace collision between regions in a monorepo (two actions both wanting `v1`)

**What goes wrong:**
Without `include-component-in-tag: true` and `tag-separator`, release-please defaults to a single `v1.0.0` tag per release. In a monorepo with three region packages, that's impossible — git can only have one `v1.0.0`. release-please errors out, or worse, only tags the first package and silently skips the others.

**Why it happens:**
Default behavior is right for single-package repos. Monorepos need explicit config.

**How to avoid:**
- `"include-component-in-tag": true` in each package stanza.
- Choose a tag separator and document it: `"tag-separator": "-"` yields tags like `nordvpn-es-v1.0.0`, `nordvpn-us-v1.0.0`, `nordvpn-fr-v1.0.0`. No collisions.
- Floating major tag naming follows the same pattern: `nordvpn-es-v1`, `nordvpn-us-v1`, `nordvpn-fr-v1`.
- README's Pin-Form section documents the full tag names and tells consumers how to reference them.
- DO NOT ship a bare `v1` tag that covers all regions — it's ambiguous which action it pins.

**Warning signs:**
- Any tag in `git tag -l` that doesn't begin with `nordvpn-`
- release-please fails with a "tag already exists" error
- Two regions pointing at the same commit SHA via the same tag

**Phase to address:**
Phase 4 (release-please wiring) and Phase 5 (floating major tag automation).

---

### Pitfall 11: `paths_released` treated as an array instead of a JSON-encoded string

**What goes wrong:**
release-please emits `paths_released` as a STRING containing JSON, not a native array ([release-please-action README](https://github.com/googleapis/release-please-action)). `if: contains(steps.release.outputs.paths_released, 'actions/nordvpn-es')` appears to work because the string happens to contain the substring — but `contains(steps.release.outputs.paths_released, 'es')` ALSO returns true (substring of "actions/nordvpn-**es**"). The floating-major-tag job triggers for the wrong package.

**Why it happens:**
GitHub Actions expressions auto-stringify in contexts that look array-shaped. `contains()` on a JSON string does substring matching, not element matching.

**How to avoid:**
- Always parse: `needs.release.outputs.paths_released_json: ${{ steps.release.outputs.paths_released }}` then in a later job matrix `matrix: include: ${{ fromJSON(needs.release.outputs.paths_released_json) }}`.
- Or use the per-component outputs: release-please emits `outputs['actions/nordvpn-es--release_created']` (dashes-dash) which is a proper boolean. Prefer that.
- For the floating-major job, use a matrix over an explicit region list, gated by the per-component `release_created` boolean, not a substring search.

**Warning signs:**
- `contains(..., paths_released, ...)` anywhere in a workflow
- Floating-major tag job runs when the wrong region was released (e.g., US release triggers ES tag update)
- `paths_released` used in an `if:` without `fromJSON()`

**Phase to address:**
Phase 5 (floating major tag automation).

---

### Pitfall 12: Floating `v1` tag force-moved mid-consumer-run produces flaky downstream workflows

**What goes wrong:**
Consumer's workflow does `uses: pau-vega/nordvpn-actions/actions/nordvpn-es@nordvpn-es-v1` at 14:00:00. Our release workflow at 14:00:05 force-pushes `nordvpn-es-v1` from commit `abc` to commit `def`. If the consumer's job does a second checkout/re-fetch mid-run (rare but happens with matrix re-entries or with manual retries of failed steps), step 1 ran against `abc` and step 2 runs against `def`. Non-reproducible CI. GitHub doesn't version-lock the action across an in-progress job, but the contract is fragile when the tag moves.

Separately: consumers who believe `v1` is immutable because they don't know `v1` is a floating tag. They pin `v1` expecting reproducibility, get patch bumps, blame us for "breaking changes."

**Why it happens:**
Developers assume tags are immutable. GitHub permits force-pushing annotated tags; it's the action ecosystem's job to document the mutability contract.

**How to avoid:**
- README "Versioning" section in every per-action README explicitly states: "The floating major tag `nordvpn-<region>-v1` is MUTABLE and moves forward on every compatible release. For reproducibility, pin to the commit SHA (byte-for-byte) or exact version tag (`nordvpn-<region>-v1.0.3`)."
- Publish SHA-pinning example first in the Usage section; floating-major second; exact-tag third. Recommend SHA for release-critical workflows.
- Floating-major automation runs strictly AFTER the release PR is merged and the exact tag exists — never concurrent with a release.
- Consider doing what `astral-sh/setup-uv` does: only publish immutable tags, skip the floating major entirely ([discussion in pinning-github-actions writeups](https://emmer.dev/blog/pin-your-github-actions-to-protect-against-mutability/)). For v1 we accept the floating tag as a convenience, but document it clearly.

**Warning signs:**
- README lacks an explicit "Pinning" or "Versioning" section
- Pin-form examples recommend `@main` (never do this — explain why in README)
- Floating-major tag job runs on a `release:` trigger from the same workflow that opens the release PR (race condition; use `release: {types: [published]}` not the release-please PR event)

**Phase to address:**
Phase 5 (floating major tag automation) for the mechanics; Phase 6 (READMEs) for the mutability contract documentation.

---

### Pitfall 13: Running the action on `macos-latest` or `windows-latest` — cryptic `apt-get: command not found`

**What goes wrong:**
Action's `install.sh` starts with `sudo apt-get update && sudo apt-get install -y openvpn openvpn-systemd-resolved`. On macOS: `apt-get: command not found`. On Windows: `sudo: command not found` before `apt-get` is even reached. The error message looks like a platform issue, not a "this action is Ubuntu-only" constraint.

**Why it happens:**
Callers assume composite actions are runner-agnostic. There's no YAML mechanism to constrain `runs-on:` from inside `action.yml`.

**How to avoid:**
- First step of every action: runner-OS check. `run: [[ "$RUNNER_OS" == "Linux" ]] || { echo "::error::This action requires ubuntu-latest. Detected: $RUNNER_OS"; exit 1; }`. Fails fast with a clear error.
- README's first line after the title: **"Requires: `runs-on: ubuntu-latest` (Ubuntu 22.04 or 24.04). macOS and Windows runners are not supported."**
- Self-test matrix explicitly pins `ubuntu-latest` — don't even attempt other OSes.

**Warning signs:**
- No OS guard as step 1 of `action.yml`
- README doesn't mention Ubuntu-only in the first paragraph
- Someone files an issue titled "doesn't work on macOS runner"

**Phase to address:**
Phase 1 (Port) adds the guard; Phase 6 (READMEs) documents the constraint.

---

## Moderate Pitfalls

### Pitfall 14: `openvpn --daemon` exits 0 before the tunnel is up; scripts race ahead

**What goes wrong:**
`openvpn --daemon --config foo.ovpn --log /tmp/openvpn.log` returns exit 0 once openvpn has forked. The tunnel isn't up. The next script step runs `curl ifconfig.co` immediately — curl uses the default route because `tun0` isn't attached yet, hits the public internet directly, returns the runner's public IP (GitHub's egress, which is NOT the exit country). verify-country fails, but for the wrong reason. Worse: occasionally the tunnel comes up just fast enough that the request succeeds, making the failure mode flaky ([OpenVPN community forum: Initialization Sequence Completed patterns](https://forums.openvpn.net/viewtopic.php?t=25036)).

**Why it happens:**
`--daemon` forks. Exit code is about "did the fork succeed," not "is the tunnel up."

**How to avoid:**
Wait loop in `connect.sh`:
```bash
deadline=$(( $(date +%s) + 60 ))
while ! grep -q "Initialization Sequence Completed" /tmp/openvpn.log; do
  [[ $(date +%s) -gt $deadline ]] && { echo "::error::OpenVPN failed to initialize in 60s"; tail -n 100 /tmp/openvpn.log; exit 1; }
  if ! pgrep -x openvpn >/dev/null; then
    echo "::error::OpenVPN process died during initialization"
    tail -n 100 /tmp/openvpn.log
    exit 1
  fi
  sleep 1
done
```
And a second check: `while ! ip -4 addr show tun0 2>/dev/null | grep -q 'inet '; do ...; done` to confirm tun0 has an IPv4 before continuing ([Arch Linux forums: tun0 IP race conditions](https://bbs.archlinux.org/viewtopic.php?id=226509)).

**Warning signs:**
- `connect.sh` has `openvpn --daemon ...` followed immediately by `curl` with no wait loop
- Intermittent failures where verify-country returns the GitHub Actions runner's public IP
- `/tmp/openvpn.log` in failed runs doesn't contain "Initialization Sequence Completed"

**Phase to address:**
Phase 1 (Port). Verify the source PR's connect script already has this; if not, it's the first fix after port.

---

### Pitfall 15: Single geo-IP provider — flakes produce false green/red

**What goes wrong:**
verify-country hits `ipinfo.io` only. Provider returns 500, returns wrong country due to stale data, or rate-limits the runner IP. Action fails despite a correctly-established tunnel, or passes when it shouldn't because ipinfo has the wrong data for that IP ([ipinfo.io blog: evaluating IP data accuracy](https://ipinfo.io/blog/evaluate-ip-data-accuracy)).

**Why it happens:**
One provider = one query = one less step to write.

**How to avoid:**
- Two independent providers (`ipinfo.io` AND `ifconfig.co`), both must return the expected ISO-2 code.
- If they disagree, fail with a diagnostic dump showing both responses.
- Optionally: a third as a tiebreaker (e.g., `ip-api.com/json`).
- Document the two-provider contract in the README — it's a feature, not an implementation detail.

**Warning signs:**
- `verify-country.sh` has one `curl` call
- Flaky failures that pass on re-run
- No response body saved to a log for post-mortem

**Phase to address:**
Phase 1 (Port) — source PR likely already does this; verify.

---

### Pitfall 16: Missing `concurrency:` on self-test — parallel runs fight over NordVPN session

**What goes wrong:**
Two self-test runs trigger in parallel (e.g., push to `main` + scheduled run + PR merge all within 30 seconds). Both establish OpenVPN connections with the same service credentials. NordVPN permits multiple concurrent connections up to a cap, but behavior when you exceed it varies — sometimes one session kills the other, sometimes both hang. The self-test becomes unreliable for reasons unrelated to the code.

**Why it happens:**
No one notices until the first double-trigger.

**How to avoid:**
```yaml
concurrency:
  group: nordvpn-selftest-${{ github.ref }}
  cancel-in-progress: false
```
Per-region: `group: nordvpn-selftest-${{ matrix.region }}-${{ github.ref }}`. `cancel-in-progress: false` so a running self-test isn't killed mid-connect (which would leak the tunnel) — new runs queue behind it ([GitHub Docs: Concurrency](https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency)).

**Warning signs:**
- No `concurrency:` block in `.github/workflows/selftest.yml`
- Logs show AUTH_FAILED intermittently during periods of high activity
- Two runs of the same workflow showing VPN steps at overlapping timestamps

**Phase to address:**
Phase 2 (Self-test workflow).

---

### Pitfall 17: NordVPN account email/password accidentally stored instead of OpenVPN service credentials

**What goes wrong:**
`NORDVPN_SERVICE_USERNAME` set to the account email, `NORDVPN_SERVICE_PASSWORD` set to the account password. OpenVPN auth fails with `AUTH: Received control message: AUTH_FAILED` in a tight reconnect loop — no useful diagnostic. Since June 14, 2023, NordVPN disabled email/password for manual OpenVPN and requires dashboard-issued service credentials ([NordVPN support: Changes to login process](https://support.nordvpn.com/hc/en-us/articles/19685514639633-Changes-to-the-login-process-on-third-party-apps-and-routers), [NordVPN support: PASSWORD Verification Failed Auth](https://support.nordvpn.com/hc/en-us/articles/19624112901009-NordVPN-PASSWORD-Verification-Failed-Auth)).

**Why it happens:**
"Username and password" means account credentials to everyone except NordVPN.

**How to avoid:**
- README "Setup" section links directly to the NordVPN dashboard service-credentials page, with a screenshot and the exact button name ("Set up NordVPN manually").
- Secret names are explicit: `NORDVPN_SERVICE_USERNAME` and `NORDVPN_SERVICE_PASSWORD`, NOT `NORDVPN_EMAIL` / `NORDVPN_PASSWORD`.
- Troubleshooting section has a specific "AUTH_FAILED in a loop" entry: "Check that you are using service credentials from the NordVPN dashboard, not your account email/password."
- connect.sh could fail fast with a friendlier error by detecting an `@` in the username ("Service credentials never contain `@`; this looks like an email address — see Troubleshooting section").

**Warning signs:**
- User issue or support request with "AUTH_FAILED"
- Service-credential user field contains `@`
- README Troubleshooting doesn't cover this specific case

**Phase to address:**
Phase 6 (READMEs) — documentation is the primary prevention surface.

---

### Pitfall 18: CODEOWNERS that only covers one region directory — new regions escape ownership

**What goes wrong:**
CODEOWNERS file contains `actions/nordvpn-es/ @pau-vega` (literal path). Adding `actions/nordvpn-us/` later, no CODEOWNERS update. PRs to the new region merge without required review because there's no owner, or the wrong auto-review behavior kicks in ([GitHub Docs: About code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners), [codeowners-validator: directory glob quirks](https://github.com/mszostok/codeowners-validator/issues/169)).

**Why it happens:**
Author writes CODEOWNERS once at project start. Forgets about it when adding regions.

**How to avoid:**
Pattern covers all regions at once:
```
/actions/ @pau-vega
/actions/**/* @pau-vega
```
The first line catches top-level files; the second recursively catches everything. Both are needed because CODEOWNERS follows gitignore pattern rules where single `*` doesn't recurse.

**Warning signs:**
- CODEOWNERS mentions specific region names
- A PR to a new region doesn't trigger an auto-request for review
- GitHub's UI shows "No code owner defined" for files in a new region

**Phase to address:**
Phase 0 (Initial scaffolding) — get the glob right on day one.

---

### Pitfall 19: Dependabot `directories` list goes stale when new regions land

**What goes wrong:**
`dependabot.yml` enumerates `/`, `/actions/nordvpn-es`, `/actions/nordvpn-es/disconnect`. Add `nordvpn-us` — if the Dependabot entry isn't updated, the new region's pinned actions (e.g., `actions/checkout` inside `action.yml`) never get patch/security updates. Silent supply-chain debt ([dependabot/dependabot-core #4993: monorepo support](https://github.com/dependabot/dependabot-core/issues/4993)).

**Why it happens:**
Easy to forget. Dependabot silently doesn't update; no error surfaces.

**How to avoid:**
- Use the `directories:` plural form (array), one entry with globs:
  ```yaml
  updates:
    - package-ecosystem: "github-actions"
      directories:
        - "/"
        - "/actions/*"
        - "/actions/*/disconnect"
      schedule:
        interval: "weekly"
  ```
- Or if the glob form doesn't work (some dependabot-core versions are literal), maintain an explicit list AND add a CI check that enumerates `/actions/*/action.yml` and verifies each parent directory is in the dependabot config.

**Warning signs:**
- Dependabot PRs stop appearing when a new region is added
- New region's action.yml references a version of `actions/checkout` that's older than what the other regions got bumped to

**Phase to address:**
Phase 0 (Initial scaffolding) — set up correctly on day one; add a lint check in Phase 3 when the second region lands.

---

### Pitfall 20: Divergent scripts across regions — ES `connect.sh` drifts from US `connect.sh`

**What goes wrong:**
Each region gets its own copy of `scripts/{connect,disconnect,install,verify-country}.sh` at port time. A bug fix goes into `nordvpn-es/scripts/connect.sh` but someone forgets `nordvpn-us/scripts/connect.sh`. Regressions only appear in the forgotten region. Over time the scripts diverge meaningfully; new regions are ported from whichever is freshest.

**Why it happens:**
Copy-paste is fastest. Shared helpers feel premature.

**How to avoid:**
Two choices — both acceptable, pick one explicitly:
1. **Template + copy with a drift lint:** Keep scripts per-region (self-contained action), but add a CI check that diffs `scripts/connect.sh` across regions and fails if they differ in anything other than the `.ovpn` path or region-specific constants. Any change must go to all regions simultaneously.
2. **Shared helpers under `actions/_shared/`:** Extract `connect-common.sh` and each region's `connect.sh` sources it. Trade-off: composite actions don't have a standard way to reference cross-action files; you'd use `${{ github.action_path }}/../_shared/connect-common.sh` which is brittle if GitHub changes how actions are checked out.

Option 1 is simpler and more robust for v1. Document the "change all three" rule in AGENTS.md.

**Warning signs:**
- `diff actions/nordvpn-es/scripts/connect.sh actions/nordvpn-us/scripts/connect.sh` returns anything other than the `.ovpn` filename
- Commit message says "fix connect script" but touches only one region

**Phase to address:**
Phase 3 (Add second region) — the moment you have two regions, add the diff-check CI step.

---

### Pitfall 21: Bundled `.ovpn` pinned to a server NordVPN decommissions

**What goes wrong:**
Bundled `vpn/nordvpn-es.ovpn` specifies `remote es123.nordvpn.com 1194`. Six months later, NordVPN decommissions that specific server. The action fails with TLS handshake errors or DNS resolution failures. Silent breakage for consumers — they discover it only when their CI starts failing ([NordVPN: servers and configuration files](https://support.nordvpn.com/hc/en-us/sections/24556948189841-NordVPN-servers-and-configuration-files)). NOTE: I couldn't find public documentation on NordVPN's server-decommission cadence — flagged as LOW-confidence prediction based on general VPN provider patterns.

**Why it happens:**
Authors bundle one server for reproducibility. Providers reshape their server fleet over time.

**How to avoid:**
- Pick a server group rather than a specific server. NordVPN config generator supports country-wide groups. The `.ovpn` can have multiple `remote` lines and OpenVPN tries them in order with `remote-random` — giving some resilience.
- Schedule a weekly cron job in `.github/workflows/heartbeat.yml` that runs the self-test against each region. If a region fails three runs in a row, the cron opens an issue automatically. That's the monitoring signal that tells you "refresh the `.ovpn`."
- Document the refresh cadence: "The bundled `.ovpn` files target specific NordVPN servers. If a server is decommissioned, the action may fail until the `.ovpn` is refreshed. Maintenance: monthly spot-check and issue triage."

**Warning signs:**
- `.ovpn` has a single `remote host port` line
- No monitoring/heartbeat workflow
- Consumer opens an issue "action suddenly broke"

**Phase to address:**
Phase 2 (Self-test) establishes the baseline; Phase 3+ adds the cron heartbeat.

---

### Pitfall 22: Self-test credential-dependent step runs without an input-presence guard — fork PRs fail loudly instead of skipping

**What goes wrong:**
Self-test job has `steps:` that reference `secrets.NORDVPN_SERVICE_USERNAME` / `secrets.NORDVPN_SERVICE_PASSWORD`. Fork PR: secrets are unavailable (`""`). OpenVPN auth fails with AUTH_FAILED, job fails red, contributor sees a scary error that looks like their code broke something. Genuine contributors get discouraged.

**Why it happens:**
Authors think about the main case (push to main, non-fork PR) and forget the fork case until a first external contribution.

**How to avoid:**
- Job-level `if:` guard: `if: github.event_name == 'push' || (github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name == github.repository)`.
- Even better: use `vars` (repository variables, not secrets) as a "VPN self-test enabled" flag. Job runs `if: vars.NORDVPN_SELFTEST_ENABLED == 'true' && ...`. Forks don't inherit repo variables either, so the flag evaluates false and the step skips with a clean status.
- Add a sibling "Self-test: skipped (fork PR)" step that runs on the inverse condition and emits a GitHub step summary explaining why. Contributor sees a green check with "VPN self-test requires maintainer secrets, skipped for forks" instead of red confusion.

**Warning signs:**
- First fork PR arrives, CI turns red without explanation
- No explicit "fork" branch in the workflow file
- `vars.NORDVPN_SERVICE_USERNAME != ''` not used anywhere

**Phase to address:**
Phase 2 (Self-test workflow).

---

### Pitfall 23: README recommends `@main` or fails to show SHA-pin form

**What goes wrong:**
Usage example in README: `uses: pau-vega/nordvpn-actions/actions/nordvpn-es@main`. Consumers copy-paste. `@main` is a moving target — every push to main (including breaking refactors between releases) changes what consumers run. When the repo gets compromised (tj-actions precedent, March 2025 — 23,000+ repos affected per [StepSecurity writeup](https://www.stepsecurity.io/blog/pinning-github-actions-for-enhanced-security-a-complete-guide)), everyone pinning `@main` runs attacker code instantly.

**Why it happens:**
`@main` is the simplest thing in the README draft. Authors forget to replace it before publishing.

**How to avoid:**
- README Usage section leads with SHA-pin form: `uses: pau-vega/nordvpn-actions/actions/nordvpn-es@<40-char-sha> # nordvpn-es-v1.0.3`. Explain that the comment is the human-readable version.
- Second example: exact-tag form (`@nordvpn-es-v1.0.3`). Third example: floating-major form (`@nordvpn-es-v1`).
- Explicit note: "Do NOT pin to `@main`. The `main` branch is not a stable interface; breaking changes land there before being released."
- CI test: grep the README for `@main` and fail the doc build if found.

**Warning signs:**
- `@main` in any example
- SHA-pin form not the first example
- No explanation of why SHA vs tag vs floating matters

**Phase to address:**
Phase 6 (READMEs).

---

### Pitfall 24: `continue-on-error: true` on a step that actually matters

**What goes wrong:**
Someone adds `continue-on-error: true` to the `verify-country` step because "sometimes the check is flaky and we don't want to fail the job." Now a failed country verification silently passes. Consumers believe their tests ran from Spain when they ran from GitHub's US region ([qmacro.org: continue-on-error pitfalls](https://qmacro.org/blog/posts/2020/07/21/continue-on-error-can-prevent-a-job-step-failure-causing-an-action-failure/)).

**Why it happens:**
Quick fix for a flake, never removed.

**How to avoid:**
- `continue-on-error` is banned from `action.yml`. Any flake is either (a) fixed upstream (retry logic inside the script with max-attempts), or (b) the failure is real and should bubble up.
- Retry logic is explicit: `for i in 1 2 3; do ... && break; sleep 5; done || exit 1`. Visible in the script, reviewable.
- Shellcheck/actionlint rule: flag `continue-on-error: true` in anything under `actions/`.

**Warning signs:**
- Any `continue-on-error: true` in `actions/**/action.yml`
- Job showing green with "verify-country" step in warnings but not errors
- Flake reports that "passed on retry"

**Phase to address:**
Phase 0 (Lint + CI skeleton) — enforce via actionlint.

---

## Minor Pitfalls

### Pitfall 25: shellcheck warnings treated as advisory instead of blocking

**What goes wrong:**
`scripts/install.sh` uses `[ $foo = bar ]` (unquoted). shellcheck warns; CI doesn't fail. Later, `$foo` contains a space — the test fails with a confusing syntax error rather than a shellcheck warning.

**How to avoid:**
Run shellcheck in strict mode (`shellcheck -S error` blocks on errors; consider `-S warning` for new repos) and fail the CI job on any exit-non-zero. No `# shellcheck disable=` without a comment explaining why.

**Phase to address:** Phase 0.

---

### Pitfall 26: Conventional-commit scope mismatch — commits don't reach the right package

**What goes wrong:**
Author writes `feat: add new connect logic` (no scope). release-please monorepo config needs the `scope` to route the commit to the right package. Commit gets processed for none or all packages depending on config.

**How to avoid:**
- CI check (e.g., `commitlint` or a simple grep) requires a scope of `nordvpn-es`, `nordvpn-us`, `nordvpn-fr`, or `deps`/`ci`/`docs` on every commit to `main`.
- PR template includes a reminder and a dropdown of valid scopes.
- Squash-merge enforced so the PR title becomes the commit message.

**Phase to address:** Phase 4 (release-please wiring).

---

### Pitfall 27: `actions/checkout` with default `fetch-depth: 1` — release-please can't compute changelog

**What goes wrong:**
release-please needs full commit history since the last release tag to compute the changelog. `actions/checkout@v4` defaults to shallow clone (fetch-depth: 1). release-please produces an empty or truncated CHANGELOG.

**How to avoid:**
In the release workflow ONLY: `with: { fetch-depth: 0 }`. Don't change this for other workflows (self-test, lint) — shallow is faster.

**Phase to address:** Phase 4.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Copy `connect.sh` per region instead of templating | New region ships same day | Drift across regions when a bugfix forgets one | Only with a CI drift-check enforcing identity |
| Skip the `disconnect/` sub-action in v0 prototypes | One fewer file to write | Every consumer workflow now has a leaked tunnel on failure | Never in shipped releases |
| Bundle one `.ovpn` with a single `remote` line | Simplest config | Silent breakage when server is decommissioned | Only with a weekly heartbeat cron to detect |
| Let `paths_released` be used as a string in `contains()` | Works for the common case | Substring false-positives trigger the wrong release job | Never |
| Use `@main` in internal examples "just for the demo" | Readers see working code immediately | The example gets copied into production workflows | Never publish; use a real tag |
| Rely on GitHub's default secret masking for step outputs | No explicit `add-mask` needed | Outputs bypass masking; credentials leak into run logs | Never — outputs must never contain secrets |
| One geo-IP provider for verify-country | One less HTTP call | Provider flake = false green/red | During initial port if provider = 2 in source PR; otherwise never |
| Floating `v1` tag that covers all regions (ambiguous) | Short pin form | Consumers can't tell which region is pinned | Never — always component-scoped: `nordvpn-es-v1` |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| NordVPN authentication | Using account email/password | Use dashboard-issued service credentials (post-June-2023 requirement) |
| OpenVPN on Ubuntu 22.04+ | Install `openvpn` without `openvpn-systemd-resolved` | Install both; `.ovpn` sets `script-security 2` + `DOMAIN-ROUTE .` |
| `openvpn --daemon` | Treat exit 0 as "tunnel up" | Poll logfile for "Initialization Sequence Completed" + wait for tun0 IPv4 |
| release-please v4 action | Use archived `google-github-actions/release-please-action` | Use `googleapis/release-please-action@<sha>` |
| release-please monorepo | Single `packages: {}` with paths `.` | Per-package stanzas, `release-type: simple`, `include-component-in-tag: true` |
| release-please outputs | `contains(outputs.paths_released, 'es')` | `fromJSON(outputs.paths_released)` or per-component boolean `outputs['actions/nordvpn-es--release_created']` |
| Geo-IP verification | One provider (`ipinfo.io` only) | Two independent providers, both must agree |
| CODEOWNERS in monorepo | Per-region literal paths | Glob pattern `/actions/` + `/actions/**/*` |
| Dependabot monorepo | Static list of directories | `directories:` array with globs + CI check that all region dirs are listed |
| `pull_request_target` for fork self-test | Use it with `actions/checkout` of PR head | NEVER; use `pull_request` + skip-on-fork guard |

## Performance Traps

Action-repo scale is bounded (dozens of releases/year, single-digit regions in v1) — classical scaling traps don't apply. But two shape-specific traps exist:

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Self-test runs on every PR regardless of which region changed | Each PR runs 3 VPN connections, burns NordVPN concurrent-session cap, slow CI | Path-filter self-test: only run the matrix entry for the changed region. Full matrix on `push` to main. | As soon as region count reaches 3+ |
| release-please runs on every push to main | CI load; release PR churn | Schedule release-please on a cron (hourly or daily) rather than on every push; or `paths:` filter to only run when `actions/**` changes | Any time |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| `pull_request_target` + fork PR checkout | ACE + secret exfiltration (GHSA-89qq-hgvp-x37m, GHSA-h25v-8c87-rvm8) | Use `pull_request` only; never check out PR code under `pull_request_target` |
| Auth file at 0644 or under `$GITHUB_WORKSPACE` | Readable by co-tenants on self-hosted; may persist across jobs | `$RUNNER_TEMP` + `install -m 0600` |
| Secrets in step outputs | Bypass GitHub's masking; permanent in run logs | Never derive outputs from secret inputs |
| `set -x` in scripts handling credentials | Shell trace prints secret command lines to logs | Use `set -euo pipefail` without `-x` |
| Floating major tag moved during compromise | Supply-chain attack propagates to all `@v1` consumers immediately (tj-actions 2025 precedent) | Document SHA-pinning as the recommended form; publish only immutable exact tags if the user base is security-critical |
| Action pinned by unqualified `@main` in examples | Every push to main runs on every consumer | README never shows `@main`; CI grep blocks `@main` in docs |
| `GITHUB_TOKEN` with default write permissions | Overly privileged for a read-only workflow | Workflow-level `permissions:` defaults to `contents: read`; escalate per-job |
| Untrusted PR input interpolated into shell | Command injection (classic pwn-request pattern) | Never `${{ github.event.pull_request.title }}` inline in `run:`; assign to env var first |
| Self-hosted runner persistence | Auth file, openvpn process, routing leaks to next job | Ubuntu-hosted only; document "self-hosted unsupported" |

## UX Pitfalls

"UX" here = consumer-developer experience (the person adding `uses:` to their workflow).

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Cryptic error on non-Linux runner | "apt-get: command not found" — seems like a platform bug | OS guard as step 1 with explicit error message |
| Cryptic error on wrong credentials | "AUTH_FAILED" loop with no hint | Troubleshooting section covers it; connect.sh hint if username contains `@` |
| No `disconnect` example in README | Consumer's next job leaks VPN state | Usage section MUST show the `if: always()` disconnect step inline |
| Pin-form confusion (SHA vs tag vs floating) | Consumer pins `@v1` expecting reproducibility, gets auto-updates | README's Versioning section explicitly names the mutability contract |
| Self-test skip on fork PRs shows as red | External contributor sees failure and gives up | Explicit "skipped (fork)" step that runs on the inverse condition |
| Per-region action with no obvious "how to add a new region" path | Fork-and-hack friction for ES-like public contributions | `AGENTS.md` documents the new-region checklist with concrete paths |

## "Looks Done But Isn't" Checklist

- [ ] **Connect step:** Verify it waits for "Initialization Sequence Completed" AND `tun0` IPv4 — not just `--daemon` exit 0
- [ ] **Disconnect step:** Runs via sibling `disconnect/` sub-action with `if: always()`, not buried in the main composite
- [ ] **DNS:** `openvpn-systemd-resolved` is installed, `.ovpn` has `script-security 2` + `DOMAIN-ROUTE .` directives, `resolvectl status` in logs shows tun0 is the DNS default
- [ ] **Auth file:** Written to `$RUNNER_TEMP`, mode 0600, removed by disconnect unconditionally
- [ ] **Geo verification:** Two independent providers (ipinfo + ifconfig.co), both assert the same country
- [ ] **No set -x:** `grep -rn 'set -x\|bash -x' actions/` returns nothing
- [ ] **No secret outputs:** `action.yml` `outputs:` block only contains non-sensitive values
- [ ] **OS guard:** First step of `action.yml` checks `RUNNER_OS == Linux`
- [ ] **release-please action URL:** `googleapis/release-please-action`, NOT `google-github-actions/release-please-action`
- [ ] **release-type:** `simple` for every package (no `package.json`/`version.txt`)
- [ ] **Component tags:** Every release uses `<region>-v<semver>` format, not bare `v<semver>`
- [ ] **paths_released:** Never used in a `contains()` without `fromJSON()` first
- [ ] **Floating major tag job:** Triggered strictly after the release PR is merged (not concurrent with release-please's PR event)
- [ ] **Fork-safe self-test:** Guarded with an ownership check + a skip-step that emits a friendly summary
- [ ] **No `pull_request_target`:** `grep pull_request_target .github/` returns nothing
- [ ] **Concurrency group:** Self-test workflow has `concurrency:` keyed to the ref (or ref+region)
- [ ] **README Usage:** Shows disconnect step, SHA-pin example first, no `@main`
- [ ] **README Troubleshooting:** Has an entry for AUTH_FAILED loops with the service-credentials hint
- [ ] **CODEOWNERS:** Glob-based, not per-region literals
- [ ] **Dependabot:** Picks up new region directories automatically (glob or enforced via CI check)

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Secret leaked to public run log | HIGH | Rotate NordVPN service credentials immediately; delete the compromised run (only removes visibility, not exfiltration risk); audit who viewed the run; document incident |
| `pull_request_target` vuln discovered post-merge | HIGH | Rotate all repository secrets; audit all recent PRs from forks; check run logs for exfil markers; publish security advisory; remove `pull_request_target` workflow and verify |
| Floating major tag force-pushed to wrong SHA | MEDIUM | Re-run the floating-major-tag workflow manually to correct; document in release notes; consumer CI will self-heal on next run |
| `.ovpn` server decommissioned | LOW-MEDIUM | Generate fresh `.ovpn` from NordVPN dashboard; update bundled file; conventional-commit `fix(nordvpn-<region>): refresh bundled ovpn`; patch release auto-follows |
| CHANGELOG generated wrong due to release-please misconfig | LOW | Revert the release-please PR; fix config; re-run; manifest drift may require manual bootstrap-sha |
| Consumer pinned `@v1` broke after compatible patch release | LOW | Actual bug → fix + re-release as patch; not a bug → document in README that floating major is mutable and recommend SHA pinning |
| DNS leak discovered post-release | MEDIUM | Patch release adds `openvpn-systemd-resolved` and `.ovpn` directives; security advisory for "silent DNS leak"; consumers bump to the patched version |
| AUTH_FAILED on real consumers due to NordVPN login-flow change | MEDIUM (if NordVPN changes the protocol) | Patch scripts; update README troubleshooting; announce via GitHub Discussions |

## Pitfall-to-Phase Mapping

Assuming a roadmap of approximately: Phase 0 = Scaffolding & Lint; Phase 1 = Port nordvpn-es; Phase 2 = Self-test; Phase 3 = Add nordvpn-us/fr; Phase 4 = release-please; Phase 5 = Floating major tag automation; Phase 6 = READMEs & documentation. Adjust if roadmap diverges.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1. Teardown in composite instead of sibling | Phase 1 | `disconnect/action.yml` exists; README Usage shows both `uses:` lines |
| 2. `pull_request_target` ACE | Phase 2 | `grep pull_request_target .github/` returns empty; fork PR skip tested |
| 3. DNS leak via missing systemd-resolved | Phase 1 | `apt install` list includes `openvpn-systemd-resolved`; verify-country includes DNS check |
| 4. Relative script paths | Phase 0 (lint) + Phase 1 (port) | actionlint/grep rule blocks `./scripts/` in `action.yml` |
| 5. Auth file in workspace at 0644 | Phase 1 | Scripts use `$RUNNER_TEMP` + `install -m 0600` |
| 6. `set -x` or secret in outputs | Phase 0 (lint) | shellcheck rule + actionlint rule for outputs referencing secret inputs |
| 7. Archived release-please-action | Phase 4 | grep check in CI; release workflow uses `googleapis/release-please-action` |
| 8. Wrong `release-type` | Phase 4 | First release-please dry-run produces correct manifest entries |
| 9. Missing path filters | Phase 4 | First release-please PR scopes to the changed package only |
| 10. Tag namespace collision | Phase 4 + Phase 5 | All tags begin with `nordvpn-<region>-v`; no bare `v<number>` |
| 11. `paths_released` substring gotcha | Phase 5 | Floating-major job uses `fromJSON()` or per-component outputs |
| 12. Floating major tag mutability undocumented | Phase 6 | README Versioning section explicit; `@main` grep blocked |
| 13. Non-Linux runner cryptic error | Phase 1 (guard) + Phase 6 (docs) | First step of action.yml has OS check; README top matter states requirement |
| 14. openvpn --daemon race | Phase 1 | connect.sh has polling loop; integration test forces a slow init |
| 15. Single geo-IP provider | Phase 1 | verify-country.sh has two `curl` calls with cross-check |
| 16. Missing concurrency group | Phase 2 | Self-test workflow YAML contains `concurrency:` |
| 17. Account credentials vs service credentials | Phase 6 | README Setup + Troubleshooting cover it; connect.sh warns on `@` in username |
| 18. CODEOWNERS per-region | Phase 0 | Pattern is `/actions/**/*`, not specific regions |
| 19. Dependabot directories stale | Phase 0 (+ Phase 3 check) | Glob or CI script verifying all regions are covered |
| 20. Script drift across regions | Phase 3 | CI diff-check on scripts between regions |
| 21. `.ovpn` server decommission | Phase 2 (baseline) + Phase 3+ (cron) | Weekly heartbeat workflow + open-issue-on-failure |
| 22. Self-test fails on fork PRs | Phase 2 | Fork PR skip-step tested; fork contributor sees green + friendly summary |
| 23. README `@main` or missing SHA example | Phase 6 | CI grep blocks `@main`; READMEs lead with SHA example |
| 24. `continue-on-error: true` on critical steps | Phase 0 | actionlint/grep rule |
| 25. shellcheck advisory | Phase 0 | `shellcheck -S error` blocks CI |
| 26. Conventional commit scope mismatch | Phase 4 | commitlint or CI check for scope on commits to main |
| 27. Shallow clone breaks release-please changelog | Phase 4 | Release workflow uses `fetch-depth: 0` |

## Sources

**Composite-action mechanics:**
- [GitHub community discussion #26743: No post run capability for composite actions](https://github.com/orgs/community/discussions/26743)
- [actions/runner #1478: Support pre and post steps in Composite Actions](https://github.com/actions/runner/issues/1478)
- [actions/runner #1348: Local composite actions always relative to top level repository](https://github.com/actions/runner/issues/1348)
- [GitHub Docs: Creating a composite action](https://docs.github.com/actions/creating-actions/creating-a-composite-action)
- [GitHub community discussion #25225: How to pass masked secrets between steps and jobs](https://github.com/orgs/community/discussions/25225)
- [actions/runner #1557: Unable to use GitHub Secret with Composite action](https://github.com/actions/runner/issues/1557)
- [actions/runner ADR 0277: run action shell options](https://github.com/actions/runner/blob/main/docs/adrs/0277-run-action-shell-options.md)

**`pull_request_target` security (ACE + secret exfiltration):**
- [GitHub Security Lab: Keeping your GitHub Actions workflows secure — preventing pwn requests](https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/)
- [GitHub Security Advisory: Secrets exfiltration via pull_request_target (timescale/pgai GHSA-89qq-hgvp-x37m)](https://github.com/timescale/pgai/security/advisories/GHSA-89qq-hgvp-x37m)
- [GitHub Security Advisory: Secrets exfiltration via pull_request_target (spotipy-dev GHSA-h25v-8c87-rvm8)](https://github.com/spotipy-dev/spotipy/security/advisories/GHSA-h25v-8c87-rvm8)
- [Orca Security: pull_request_nightmare Part 2: Exploiting GitHub Actions for RCE and Supply Chain](https://orca.security/resources/blog/pull-request-nightmare-part-2-exploits/)
- [Unit 42: GitHub Actions Supply Chain Attack (April 2026 hackerbot-claw campaign)](https://unit42.paloaltonetworks.com/github-actions-supply-chain-attack/)
- [GitHub Changelog: Actions pull_request_target and environment branch protections (2025-11-07)](https://github.blog/changelog/2025-11-07-actions-pull_request_target-and-environment-branch-protections-changes/)
- [StepSecurity: Pinning GitHub Actions for Enhanced Security (tj-actions March 2025 incident)](https://www.stepsecurity.io/blog/pinning-github-actions-for-enhanced-security-a-complete-guide)

**release-please (monorepo, components, archive migration):**
- [googleapis/release-please-action (canonical)](https://github.com/googleapis/release-please-action)
- [google-github-actions/release-please-action (archived)](https://github.com/google-github-actions/release-please-action)
- [googleapis/release-please #2288: Action moved from google-github-actions to googleapis](https://github.com/googleapis/release-please/issues/2288)
- [release-please manifest-releaser docs](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md)
- [googleapis/release-please #2397: Initial version in manifest file being ignored](https://github.com/googleapis/release-please/issues/2397)
- [Beware the Release Please v4 GitHub Action! (Wakeem's World)](https://danwakeem.medium.com/beware-the-release-please-v4-github-action-ee71ff9de151)

**OpenVPN + systemd-resolved DNS leaks:**
- [systemd/systemd #7182: systemd-resolved causes dns leaks when connected via vpn](https://github.com/systemd/systemd/issues/7182)
- [jonathanio/update-systemd-resolved README](https://github.com/jonathanio/update-systemd-resolved)
- [OpenVPN community: Initialization Sequence Completed patterns](https://forums.openvpn.net/viewtopic.php?t=25036)
- [Arch Linux forums: tun0 IP race conditions](https://bbs.archlinux.org/viewtopic.php?id=226509)
- [Arch Linux forums: Prevent DNS leak with update-systemd-resolved](https://bbs.archlinux.org/viewtopic.php?id=226509)

**NordVPN-specific:**
- [NordVPN: Changes to login process on third-party apps and routers (June 2023)](https://support.nordvpn.com/hc/en-us/articles/19685514639633-Changes-to-the-login-process-on-third-party-apps-and-routers)
- [NordVPN: PASSWORD Verification Failed Auth troubleshooting](https://support.nordvpn.com/hc/en-us/articles/19624112901009-NordVPN-PASSWORD-Verification-Failed-Auth)
- [qdm12/gluetun discussion #1710: NordVPN authentication error](https://github.com/qdm12/gluetun/discussions/1710)

**Tag mutability + SHA pinning:**
- [GitHub Changelog: Actions policy supports blocking and SHA pinning (2025-08-15)](https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/)
- [Pin Your GitHub Actions to Protect Against Mutability (Christian Emmer)](https://emmer.dev/blog/pin-your-github-actions-to-protect-against-mutability/)
- [Pinning GitHub Actions (Carlos Becker)](https://carlosbecker.com/posts/pinning-github-actions/)

**Concurrency + CODEOWNERS + Dependabot:**
- [GitHub Docs: Concurrency](https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency)
- [GitHub Docs: About code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- [dependabot/dependabot-core #4993: Dependabot monorepo support](https://github.com/dependabot/dependabot-core/issues/4993)
- [GitHub Docs: Configuring Dependabot version updates](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/configuring-dependabot-version-updates)

**continue-on-error anti-pattern:**
- [qmacro.org: continue-on-error can prevent a job step failure causing an action failure](https://qmacro.org/blog/posts/2020/07/21/continue-on-error-can-prevent-a-job-step-failure-causing-an-action-failure/)
- [Simon Willison's TILs: Skipping a GitHub Actions step without failing](https://til.simonwillison.net/github-actions/continue-on-error)

---
*Pitfalls research for: Composite GitHub Actions monorepo with VPN + release-please + self-test*
*Researched: 2026-04-24*
