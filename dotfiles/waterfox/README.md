# Waterfox Profile Config

## Profile Location

`~/.waterfox/2d3dycuv.default-release/`

## user.js

Overrides Waterfox prefs on every launch. Enables:

- **Widevine CDM** — DRM playback for embedded video (e.g. cyberwarfare.live)
- **Tracking protection off** — prevents cross-origin embed breakage
- **LinkedIn fixes** — touch events, fingerprinting resistance off, webcompat shims on

## Deploy on Fresh Install

```bash
mkdir -p ~/.waterfox/<profile-dir>/
cp user.js ~/.waterfox/<profile-dir>/user.js
```

Then launch Waterfox once so it downloads the Widevine CDM binary into `gmp-widevinecdm/` under the profile directory.

## Verify Widevine

1. Open `about:addons` → Plugins → confirm "Widevine Content Decryption Module" is listed
2. Check `~/.waterfox/<profile-dir>/gmp-widevinecdm/` contains a version directory with the CDM binary