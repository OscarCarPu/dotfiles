// ==UserScript==
// @name         UOC Aula autosubmit
// @namespace    dotfiles
// @description  Submits the UOC Shibboleth login form (id-provider.uoc.edu) once the password manager has autofilled it. No credentials stored here — they live in LibreWolf's password manager.
// @match        *://id-provider.uoc.edu/*
// @run-at       document-idle
// @grant        GM_info
// @version      3.1
// ==/UserScript==
//
// Real form (dumped from id-provider.uoc.edu):
//   <form id="identification-form" method="post"
//         action="/idp/profile/SAML2/Redirect/SSO?execution=e1s1">
//     <input id="username" name="j_username" type="text" required>
//     <input id="password" name="j_password" type="password" required>
//     <button id="submit-identification-form" type="submit" name="_eventId_proceed">
//   </form>
// Shibboleth needs `_eventId_proceed` in the POST, so we must submit *through the
// button* (requestSubmit(button) / button.click()), never a bare form.submit().
(function () {
  'use strict';

  console.log('[uoc-autosubmit] loaded on', location.host);

  const MAX_WAIT_MS = 12000; // SSO bounces can be slow; keep retrying.
  const start = Date.now();
  let done = false;

  function attempt() {
    if (done) return true;
    if (Date.now() - start > MAX_WAIT_MS) return true; // give up quietly

    const pw = document.querySelector('#password, input[type="password"]');
    if (!pw || !pw.value) return false; // not autofilled yet — keep polling

    const form = pw.form || pw.closest('form');
    if (!form) return false;

    // Require the username too, so we never submit a half-filled form.
    const user = form.querySelector('#username, input[name="j_username"], input[type="text"]');
    if (user && !user.value) return false;

    // The named submit button carries _eventId_proceed — submit through it.
    const btn =
      form.querySelector('#submit-identification-form') ||
      form.querySelector('button[type="submit"][name], button[type="submit"], input[type="submit"]');

    done = true;
    console.log('[uoc-autosubmit] fields filled, submitting via', btn ? btn.id || btn.outerHTML.slice(0, 60) : 'form.submit()');

    if (typeof form.requestSubmit === 'function' && btn) {
      try { form.requestSubmit(btn); return true; } catch (e) { /* fall through */ }
    }
    if (btn) { btn.click(); return true; }
    form.submit(); // last resort (won't include _eventId_proceed)
    return true;
  }

  const poll = setInterval(() => { if (attempt()) clearInterval(poll); }, 200);
})();
