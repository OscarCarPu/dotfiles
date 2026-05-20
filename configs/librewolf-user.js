// Applied at every startup; overrides prefs.js values.
// Companion to librewolf.overrides.cfg — covers the profile layer.
user_pref("privacy.sanitize.sanitizeOnShutdown", false);
user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", false);
user_pref("network.cookie.lifetimePolicy", 0);
user_pref("browser.startup.page", 0); // blank startup — tabs come from startup_apps.sh
user_pref("browser.sessionstore.resume_from_crash", false);
