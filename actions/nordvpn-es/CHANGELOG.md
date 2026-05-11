# Changelog

## 0.1.0 (2026-05-11)


### Features

* **nordvpn-es:** port action.yml with 6 outputs and retry loop ([d29d6d6](https://github.com/pau-vega/nordvpn-action/commit/d29d6d69ad14d2493b0a052140d82f31498583e1))
* **nordvpn-es:** port disconnect.sh - best-effort cleanup ([b7b2f59](https://github.com/pau-vega/nordvpn-action/commit/b7b2f593335dead5ded6daa21dc4c24fb0a0862b))
* **nordvpn-es:** port disconnect/action.yml sibling sub-action ([6b19620](https://github.com/pau-vega/nordvpn-action/commit/6b19620b57d4d69e26649c934207d235a41d3459))
* **nordvpn-es:** port install.sh, connect.sh, verify-country.sh ([05a0500](https://github.com/pau-vega/nordvpn-action/commit/05a0500dc12ee4d85916f3c9d6170038ee731203))
* **nordvpn-es:** port nordvpn-es.ovpn with CA cert ([60bf408](https://github.com/pau-vega/nordvpn-action/commit/60bf4088712ecc32da126220067aca5850fa2082))


### Bug Fixes

* add tunnel stabilization delay + increase curl timeout ([ebf2e81](https://github.com/pau-vega/nordvpn-action/commit/ebf2e81da91261261355d3bb6b4cac5ef2bc48cf))
* **nordvpn-es,nordvpn-us,nordvpn-fr:** match Tutellus OVPN exactly — add tls-auth + key-direction ([4364053](https://github.com/pau-vega/nordvpn-action/commit/436405301c6aaee98364ad12d15b0fd58ce488f2))
* **nordvpn-es,nordvpn-us,nordvpn-fr:** remove static remote lines from OVPN configs ([d9fd7b7](https://github.com/pau-vega/nordvpn-action/commit/d9fd7b749779c5f9fc94b49fcb927db1eaf903c0))
* **nordvpn-es,nordvpn-us,nordvpn-fr:** replace corrupted CA certs with NordVPN Root CA ([f98b636](https://github.com/pau-vega/nordvpn-action/commit/f98b63624082bedcdbc43bd0e8b2dd35310f7a2c))
* **nordvpn-es,nordvpn-us,nordvpn-fr:** switch from UDP to TCP for Azure runner compat ([220b148](https://github.com/pau-vega/nordvpn-action/commit/220b148021772b2d7085d88236faf3c33f3c59dc))
* **nordvpn-es,nordvpn-us,nordvpn-fr:** switch to official NordVPN TCP template ([8f13cdd](https://github.com/pau-vega/nordvpn-action/commit/8f13cdd2278d5bb9530c0041abd55d2b8e5c9d17))
* relax geo verification — primary must match, secondary advisory ([bb18998](https://github.com/pau-vega/nordvpn-action/commit/bb189985d9c77b5c8a2ad11f4188a4c0b047450c))
* use station IP direct + TCP port 1194 ([dd6431b](https://github.com/pau-vega/nordvpn-action/commit/dd6431b71d0ceea652ed694e0a5646f0b9379723))


### Documentation

* correct repo name to nordvpn-action across active files ([ded2c78](https://github.com/pau-vega/nordvpn-action/commit/ded2c782b1d0147f62c781520a5e21aaeed5bc0b))
* **nordvpn-es:** port and rewrite README.md ([832d6f6](https://github.com/pau-vega/nordvpn-action/commit/832d6f697a776f977c863d3cf5034cdfd47be6e9))
