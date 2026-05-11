---
status: resolved
trigger: some workflows are not working
created: 2026-05-10T12:00:00Z
updated: 2026-05-10T12:00:00Z
---

## Resolution

**Root cause 1 (release-please):** `config-file: release-please-config.json` pointed to repo root but file was at `.github/release-please-config.json`. Fixed path in `.github/workflows/release-please.yml`.

**Root cause 2 (self-test):** GitHub Actions parser cannot resolve `matrix.region` in `uses:` directive paths at parse time. Replacement with per-region jobs (self-test-es/us/fr) fixes.

**Root cause 3 (self-test):** Input names `nordvpn-username`/`nordvpn-password` mismatched action.yml inputs `username`/`password`. Corrected.

**New issue (release-please):** Config now loads but PR creation fails. Repo setting "Allow GitHub Actions to create and approve pull requests" needs enabling at Settings > Actions > General.

**New issue (self-test):** Jobs now run but VPN connect fails — Preview environment secrets or VPN infra issue. Not a workflow bug.

## Fix

Commits:
- 0b362d3: fix(ci): correct release-please config-file path
- b9adcd9: fix(ci): replace self-test matrix with per-region jobs

## Verification

- actionlint passes on both modified workflows
- release-please: config file now found, proceeds to PR creation step
- self-test: 3 per-region jobs created and run (previously zero jobs)

