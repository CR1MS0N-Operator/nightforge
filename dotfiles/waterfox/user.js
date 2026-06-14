// NightForge v3 — Waterfox profile overrides
// Enables Widevine DRM, relaxes tracking protection for embedded video,
// and fixes LinkedIn DOM compatibility.

// Widevine CDM
user_pref("media.eme.enabled", true);
user_pref("media.gmp-widevinecdm.abi", "x86_64-gcc3");
user_pref("media.gmp-widevinecdm.autoupdate", true);
user_pref("media.gmp-widevinecdm.enabled", true);

// Tracking protection — disable globally (use per-site exceptions if preferred)
user_pref("privacy.trackingprotection.enabled", false);

// LinkedIn compatibility
user_pref("dom.w3c_touch_events.enabled", 1);
user_pref("privacy.resistFingerprinting", false);
user_pref("webcompat.enable_shims", true);