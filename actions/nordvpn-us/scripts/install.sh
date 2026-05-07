#!/usr/bin/env bash
# Installs the OpenVPN 2 toolchain + systemd-resolved hooks used by the .ovpn file's
# `up /etc/openvpn/update-systemd-resolved` directive. Asserts curl/jq/openvpn after install.
set -euo pipefail
# NEVER set -x — leaks credentials via transformed log lines elsewhere in the pipeline.

# Chaos injection: uninstall openvpn when called from smoke workflow's `missing-openvpn`
# failure mode. Exit 0 here so the failure surfaces at connect.sh's `command -v openvpn`
# or at openvpn invocation (failure at the expected step).
if [[ "${SMOKE_UNINSTALL_OPENVPN:-0}" == "1" ]]; then
  echo "[install.sh] SMOKE_UNINSTALL_OPENVPN set — removing openvpn before verify."
  sudo apt-get remove -y openvpn openvpn-systemd-resolved >/dev/null 2>&1 || true
  # Be strict: when sourced, `return` works; when executed, `exit` is needed.
  # shellcheck disable=SC2317 # `exit 0` is the fallback when `return 0` fails (executed, not sourced); both branches are reachable depending on invocation mode
  return 0 2>/dev/null || exit 0
fi

sudo apt-get update -qq
sudo apt-get install -y openvpn openvpn-systemd-resolved

# Toolbox assertion — `::error::` surfaces the line in the job summary.
command -v openvpn  >/dev/null || { echo "::error::openvpn missing after install"; exit 1; }
command -v curl     >/dev/null || { echo "::error::curl missing"; exit 1; }
command -v jq       >/dev/null || { echo "::error::jq missing"; exit 1; }
[[ -x /etc/openvpn/update-systemd-resolved ]] || { echo "::error::DNS hook /etc/openvpn/update-systemd-resolved missing after install"; exit 1; }

echo "[install.sh] openvpn $(openvpn --version | head -n1)"
