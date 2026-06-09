// Applied at every startup; overrides prefs.js values.
// Companion to librewolf.overrides.cfg — covers the profile layer.
user_pref("privacy.sanitize.sanitizeOnShutdown", false);
user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", false);
user_pref("network.cookie.lifetimePolicy", 0);
user_pref("browser.startup.page", 0); // blank startup — tabs come from startup_apps.sh
user_pref("browser.sessionstore.resume_from_crash", false);

// LibreWolf disables the password manager by default (rememberSignons=false in
// librewolf.cfg), which stops saved logins from autofilling. Re-enable it so the
// saved id-provider.uoc.edu login autofills on load (the uoc-aula-autosubmit
// userscript then submits the form).
user_pref("signon.rememberSignons", true);
user_pref("signon.autofillForms", true);
