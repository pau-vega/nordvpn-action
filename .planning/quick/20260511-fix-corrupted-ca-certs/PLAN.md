---
id: 20260511-fix-corrupted-ca-certs
date: 2026-05-11
description: Fix corrupted NordVPN CA certificates causing self-test failures
status: complete
---

# Plan: Fix Corrupted CA Certificates

## Root Cause

GitHub Actions self-test logs showed `OpenSSL: error:04800064:PEM routines::bad base64 decode` across all 3 regions. The CA certificates in `actions/nordvpn-{es,us,fr}/vpn/nordvpn-{region}.ovpn` had corrupted base64 content with variable-length lines (59-65 chars instead of standard 64 chars).

OpenSSL 3.x on Ubuntu 24.04 (noble) runners rejects malformed PEM CA certs, while older OpenSSL versions were more lenient.

## Tasks

1. **Replace corrupted CA certs** — Fetch correct NordVPN Root CA (`C=PA, O=NordVPN, CN=NordVPN Root CA`, valid 2016-2035) from official NordVPN CDN (`downloads.nordcdn.com/configs/archives/servers/ovpn.zip`).
2. **Add `remote-cert-tls server`** — Missing security directive from all 3 OVPN files. Official NordVPN configs include this.
3. **Verify all certs with OpenSSL** — Run `openssl x509 -text -noout` against each updated PEM.
4. **Push and test** — Push to main, trigger self-test workflow, verify all 3 regions pass.

## Verification

- [x] OpenSSL validates all 3 CA certs: SHA256 Fingerprint=8B:5A:49:5D:...
- [x] All base64 lines are exactly 64 characters
- [x] `remote-cert-tls server` present in all 3 OVPN files
- [x] shellcheck passes (unchanged — OVPN files only)
- [x] actionlint passes (unchanged)
- [ ] Self-test workflow passes on GitHub (pending)
