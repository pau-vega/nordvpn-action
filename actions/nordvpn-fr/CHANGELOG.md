# Changelog

## 0.1.0 (2026-05-11)


### Features

* **03-02:** mirror nordvpn-es → nordvpn-fr (country=FR, id=76) ([c3bdcdb](https://github.com/pau-vega/nordvpn-action/commit/c3bdcdbced7a0090ff49e8c1fb0e92f9dcf6119d))


### Bug Fixes

* add tunnel stabilization delay + increase curl timeout ([ebf2e81](https://github.com/pau-vega/nordvpn-action/commit/ebf2e81da91261261355d3bb6b4cac5ef2bc48cf))
* **nordvpn-es,nordvpn-us,nordvpn-fr:** match Tutellus OVPN exactly — add tls-auth + key-direction ([4364053](https://github.com/pau-vega/nordvpn-action/commit/436405301c6aaee98364ad12d15b0fd58ce488f2))
* **nordvpn-es,nordvpn-us,nordvpn-fr:** remove static remote lines from OVPN configs ([d9fd7b7](https://github.com/pau-vega/nordvpn-action/commit/d9fd7b749779c5f9fc94b49fcb927db1eaf903c0))
* **nordvpn-es,nordvpn-us,nordvpn-fr:** replace corrupted CA certs with NordVPN Root CA ([f98b636](https://github.com/pau-vega/nordvpn-action/commit/f98b63624082bedcdbc43bd0e8b2dd35310f7a2c))
* **nordvpn-es,nordvpn-us,nordvpn-fr:** switch from UDP to TCP for Azure runner compat ([220b148](https://github.com/pau-vega/nordvpn-action/commit/220b148021772b2d7085d88236faf3c33f3c59dc))
* **nordvpn-es,nordvpn-us,nordvpn-fr:** switch to official NordVPN TCP template ([8f13cdd](https://github.com/pau-vega/nordvpn-action/commit/8f13cdd2278d5bb9530c0041abd55d2b8e5c9d17))
* **nordvpn-fr,nordvpn-us:** correct NordVPN API country_id values ([434e239](https://github.com/pau-vega/nordvpn-action/commit/434e239cafe7283dfbf2e6bbb39a7059486a5f2a))
* relax geo verification — primary must match, secondary advisory ([bb18998](https://github.com/pau-vega/nordvpn-action/commit/bb189985d9c77b5c8a2ad11f4188a4c0b047450c))
* use station IP direct + TCP port 1194 ([dd6431b](https://github.com/pau-vega/nordvpn-action/commit/dd6431b71d0ceea652ed694e0a5646f0b9379723))


### Documentation

* correct repo name to nordvpn-action across active files ([ded2c78](https://github.com/pau-vega/nordvpn-action/commit/ded2c782b1d0147f62c781520a5e21aaeed5bc0b))
