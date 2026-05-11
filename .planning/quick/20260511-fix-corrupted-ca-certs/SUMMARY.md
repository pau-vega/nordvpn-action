---
status: complete
date: 2026-05-11
description: Fix corrupted NordVPN CA certificates causing self-test failures
commit: f98b636
---

# Summary: Fix Corrupted CA Certificates

## Root Cause

All 3 OVPN files (`nordvpn-es`, `nordvpn-us`, `nordvpn-fr`) contained corrupted CA certificates with variable-length base64 lines. OpenSSL 3.x on Ubuntu 24.04 (noble) runners rejected these as `bad base64 decode`, causing the `Cannot load CA certificate file [[INLINE]]` fatal error in all `Connect NordVPN` steps.

The corruption likely occurred during the port from the Tutellus source PR — the CA base64 data was concatenated at a non-standard wrapping width, resulting in lines of 59-65 characters instead of the PEM-standard 64 characters.

## Fix Applied

1. **CA certs replaced** with the official NordVPN Root CA (`C=PA, O=NordVPN, CN=NordVPN Root CA`, SHA256 fingerprint: `8B:5A:49:5D:...`, valid 2016-01-01 to 2035-12-31), sourced from NordVPN's public CDN (`downloads.nordcdn.com/configs/archives/servers/ovpn.zip`).

2. **Added `remote-cert-tls server`** to all 3 OVPN configurations. This was present in the official NordVPN configs but missing from the ported versions. It enforces that the server certificate has the `serverAuth` extended key usage — a defense against MITM attacks.

## Files Changed

- `actions/nordvpn-es/vpn/nordvpn-es.ovpn` (CA cert + remote-cert-tls)
- `actions/nordvpn-us/vpn/nordvpn-us.ovpn` (CA cert + remote-cert-tls)
- `actions/nordvpn-fr/vpn/nordvpn-fr.ovpn` (CA cert + remote-cert-tls)

## Verification

- All 3 CA certs validate with `openssl x509 -text -noout`
- All base64 lines are exactly 64 characters
- shellcheck and actionlint pass unchanged
- Self-test triggered on push to main — run #25655233281
