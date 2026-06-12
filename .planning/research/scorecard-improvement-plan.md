# OpenSSF Scorecard Improvement Plan

> Status: **planned, not executed**. Research captured from a live Scorecard API
> run; implementation deferred until approved.

## Baseline

- **Score:** `6.3 / 10`
- **Scorecard version:** v5.3.0 (`c22063e`)
- **Analyzed commit:** `f2500c5`
- **Source:** `https://api.securityscorecards.dev/projects/github.com/pau-vega/nordvpn-action`

The repo already passes most checks. Failures, ranked by weight × gap:

| Check                | Score      | Weight   | Status                          |
|----------------------|------------|----------|---------------------------------|
| Token-Permissions    | **0**      | High     | Fixable now — easy (Tier 1a)    |
| Branch-Protection    | **-1 err** | High     | Token can't read rules (Tier 1b)|
| Maintained           | **0**      | High     | Auto-resolves (repo <90 days)   |
| Code-Review          | **0**      | High     | Structurally hard (solo repo)   |
| Signed-Releases      | **-1**     | High     | No releases yet (Tier 3)        |
| CII-Best-Practices   | **0**      | Low      | Register + questionnaire (Tier 2)|
| Contributors         | **3**      | Low      | Needs multiple orgs             |
| Fuzzing              | **0**      | Medium   | N/A for Bash                    |
| Packaging            | **-1**     | Medium   | N/A (composite action)          |

Passing (10): Dangerous-Workflow, Pinned-Dependencies, SAST, Vulnerabilities,
Security-Policy, License, Binary-Artifacts, CI-Tests, Dependency-Update-Tool.

---

## Tier 1 — Code changes (highest impact)

### 1a. Token-Permissions (0 → 10) — `.github/workflows/release-please.yml`

Sole offender: top-level `contents: write` (lines 7-10). Scorecard fails the
whole check for *any* top-level write. Fix = scope writes to the jobs.

- Replace top-level block (lines 7-10) with:
  ```yaml
  permissions:
    contents: read
  ```
- Add to `release-please:` job:
  ```yaml
  permissions:
    contents: write
    issues: write
    pull-requests: write
  ```
- Add to `tag-floating-major:` job (does `git push --force` with default token):
  ```yaml
  permissions:
    contents: write
  ```

Behavior identical; just least-privilege scoping. No top-level write remains
anywhere in the repo.

### 1b. Branch-Protection (-1 error → ~8-10) — `.github/workflows/scorecard.yml`

Error: `some github tokens can't read classic branch protection rules`. The
default `GITHUB_TOKEN` lacks admin read. Supply a PAT.

- **Manual prerequisite:** create PAT, add as repo secret `SCORECARD_TOKEN`.
  - Classic: `repo` scope, **or**
  - Fine-grained (preferred): repo `pau-vega/nordvpn-action`, permissions
    Administration:read + Contents:read + Metadata:read.
- Code change in the "Run analysis" step:
  ```yaml
  - name: Run analysis
    uses: ossf/scorecard-action@4eaacf0543bb3f2c246792bd56e8cdeffafb205a # v2.4.3
    with:
      results_file: results.sarif
      results_format: sarif
      repo_token: ${{ secrets.SCORECARD_TOKEN }}
      publish_results: true
  ```

Existing protection (`enforce_admins: true`, required checks, no force-push/
delete) should then score well instead of erroring.

---

## Tier 2 — OpenSSF Best Practices badge (CII 0 → up to 10, Low weight)

- **Manual:** register at https://www.bestpractices.dev, complete the "passing"
  questionnaire (repo already satisfies most: LICENSE, SECURITY.md,
  CONTRIBUTING, CI, SAST). Obtain a project ID.
- Code change — add badge to `README.md` top badge row (lines 5-8):
  ```markdown
  [![OpenSSF Best Practices](https://www.bestpractices.dev/projects/<PROJECT_ID>/badge)](https://www.bestpractices.dev/projects/<PROJECT_ID>)
  ```
  Scorecard's CII check reads the badge URL from the README.

---

## Tier 3 — Documented for the future (no action now)

- **Signed-Releases (-1, High):** after the first real release, add
  `actions/attest-build-provenance` to generate artifact attestations so this
  check can score.
- **Maintained (0, High):** time-based only — auto-resolves past 90 days with
  ongoing commit/PR/issue activity. No action.
- **Code-Review (0, High):** hard for a solo maintainer (can't approve own PRs).
  Revisit if a second maintainer/org joins.
- **Contributors (3, Low):** needs contributors from multiple orgs — not
  actionable solo.
- **Fuzzing (0, Medium) / Packaging (-1, Medium):** N/A for a Bash composite
  action.

---

## Execution checklist (when approved)

1. Edit `release-please.yml` (Tier 1a) — self-contained.
2. Edit `scorecard.yml` (Tier 1b) — inert until `SCORECARD_TOKEN` exists.
3. Edit `README.md` badge (Tier 2) — needs project ID.
4. Validate: `actionlint .github/workflows/*.yml`.
5. Commit (Conventional Commits), e.g.:
   - `fix(scorecard): scope release-please perms to job level`
   - `ci(scorecard): pass repo_token for branch-protection check`
   - `docs(readme): add OpenSSF Best Practices badge`

## Expected outcome

Tier 1 drives most of the gain (two High-weight checks). CII is Low-weight
(small bump). Realistic ceiling is high-7s/low-8s while Maintained matures;
Code-Review, Fuzzing, and Contributors zeros cap a solo Bash project below 9.
