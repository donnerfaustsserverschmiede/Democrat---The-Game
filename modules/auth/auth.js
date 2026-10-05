import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "./auth-config-v2.js?v=20261001-2";
import * as character from "../character/character.js?v=20261005-1";

const root = document.querySelector("#auth-app");

let supabase = null;
if (!SUPABASE_PUBLISHABLE_KEY.startsWith("REPLACE_")) {
  supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
}

function renderEntry() {
  root.innerHTML = `
    <div class="auth-shell">
      <section class="auth-card">
        <div class="auth-brand">
          <img class="game-logo auth-logo" src="./assets/democrat-logo.svg" alt="Democrat – The Game">
        </div>

        <div class="auth-actions">
          <button class="auth-button auth-button-primary" data-action="login">Anmelden</button>
          <button class="auth-button" data-action="register">Registrieren</button>
          <button class="auth-button" data-action="guest">Als Gast spielen</button>
        </div>
      </section>
    </div>
  `;

  root.querySelector('[data-action="login"]').addEventListener("click", () => renderLogin());
  root.querySelector('[data-action="register"]').addEventListener("click", () => renderRegister());
  root.querySelector('[data-action="guest"]').addEventListener("click", () => renderGuest());
}

function renderLogin(message = "") {
  root.innerHTML = `
    <div class="auth-shell">
      <section class="auth-card">
        <button class="auth-back" data-action="back">← Zurück</button>
        <h2>Anmelden</h2>
        <p class="auth-description">Mit deinem bestehenden Konto anmelden.</p>
        ${message ? `<div class="auth-message" role="alert">${escapeHtml(message)}</div>` : ""}
        <form id="login-form" class="auth-form">
          <label>E-Mail
            <input name="email" type="email" autocomplete="email" required>
          </label>
          <label>Passwort
            <input name="password" type="password" autocomplete="current-password" required>
          </label>
          <button class="auth-button auth-button-primary" type="submit">Anmelden</button>
        </form>
      </section>
    </div>
  `;

  root.querySelector('[data-action="back"]').addEventListener("click", renderEntry);
  root.querySelector("#login-form").addEventListener("submit", handleLogin);
}

function renderRegister(message = "") {
  root.innerHTML = `
    <div class="auth-shell">
      <section class="auth-card">
        <button class="auth-back" data-action="back">← Zurück</button>
        <h2>Registrieren</h2>
        <p class="auth-description">Erstelle ein neues Spieler-Konto.</p>
        ${message ? `<div class="auth-message" role="alert">${escapeHtml(message)}</div>` : ""}
        <form id="register-form" class="auth-form">
          <label>Profilname
            <input name="profileName" type="text" maxlength="32" autocomplete="nickname" required>
          </label>
          <label>E-Mail
            <input name="email" type="email" autocomplete="email" required>
          </label>
          <label>Passwort
            <input name="password" type="password" minlength="8" autocomplete="new-password" required>
          </label>
          <label>Passwort bestätigen
            <input name="passwordConfirm" type="password" minlength="8" autocomplete="new-password" required>
          </label>
          <button class="auth-button auth-button-primary" type="submit">Konto erstellen</button>
        </form>
      </section>
    </div>
  `;

  root.querySelector('[data-action="back"]').addEventListener("click", renderEntry);
  root.querySelector("#register-form").addEventListener("submit", handleRegister);
}

function renderGuest(message = "") {
  root.innerHTML = `
    <div class="auth-shell">
      <section class="auth-card">
        <button class="auth-back" data-action="back">← Zurück</button>
        <h2>Als Gast spielen</h2>
        <p class="auth-description">Kein Konto nötig. Gib nur einen Benutzernamen ein.</p>
        ${message ? `<div class="auth-message" role="alert">${escapeHtml(message)}</div>` : ""}
        <form id="guest-form" class="auth-form">
          <label>Benutzername
            <input name="profileName" type="text" maxlength="32" minlength="2" autocomplete="nickname" required>
          </label>
          <button class="auth-button auth-button-primary" type="submit">Als Gast starten</button>
        </form>
      </section>
    </div>
  `;

  root.querySelector('[data-action="back"]').addEventListener("click", renderEntry);
  root.querySelector("#guest-form").addEventListener("submit", handleGuest);
}

async function handleGuest(event) {
  event.preventDefault();
  if (!supabase) return renderGuest("Die Authentifizierung ist noch nicht konfiguriert.");

  const form = new FormData(event.currentTarget);
  const profileName = String(form.get("profileName") || "").trim();
  if (profileName.length < 2 || profileName.length > 32) {
    return renderGuest("Der Benutzername muss zwischen 2 und 32 Zeichen lang sein.");
  }

  const { data: existingSession } = await supabase.auth.getSession();
  if (existingSession?.session?.user?.is_anonymous) {
    await mountCharacterCreation(existingSession.session.user);
    return;
  }

  const { data, error } = await supabase.auth.signInAnonymously({
    options: { data: { profile_name: profileName } }
  });
  if (error || !data?.user) {
    console.error("[Democrat] Guest login error:", error);
    const code = String(error?.code || "");
    const msg = String(error?.message || "");
    if (code === "anonymous_provider_disabled" || /anonymous.*disabled|anonymous.*not.*enabled/i.test(msg)) {
      return renderGuest("Der Gastmodus ist auf dem Auth-Server noch nicht aktiviert.");
    }
    return renderGuest("Der Gastmodus konnte nicht gestartet werden. Bitte versuche es erneut.");
  }

  const { error: profileError } = await supabase.rpc("set_guest_profile", { p_profile_name: profileName });
  if (profileError) {
    console.error("[Democrat] Guest profile error:", profileError);
    await supabase.auth.signOut();
    return renderGuest("Der Gast wurde angemeldet, aber der Benutzername konnte nicht gespeichert werden.");
  }

  await mountCharacterCreation(data.user);
}

async function upgradeGuestAccount({ email, password }) {
  if (!supabase) throw new Error("auth_not_configured");
  const { data: sessionData } = await supabase.auth.getSession();
  const current = sessionData?.session?.user;
  if (!current) throw new Error("not_authenticated");
  if (!current.is_anonymous) throw new Error("not_guest");

  const profileName = String(current.user_metadata?.profile_name || "").trim();
  const { data, error } = await supabase.auth.updateUser({
    email: String(email || "").trim(),
    password: String(password || ""),
    data: { profile_name: profileName }
  });
  if (error) throw error;

  if (profileName) {
    const { error: profileError } = await supabase.rpc("sync_profile_name", {
      p_profile_name: profileName
    });
    if (profileError) throw profileError;
  }

  return data?.user || current;
}

export async function upgradeGuestAccountFromSettings(credentials) {
  return upgradeGuestAccount(credentials);
}

async function mountCharacterCreation(user) {
  root.hidden = true;
  await character.mount(user);
}

async function restoreExistingSession() {
  if (!supabase) return;
  const { data } = await supabase.auth.getSession();
  if (data.session?.user) await mountCountrySelection(data.session.user);
}

async function handleLogin(event) {
  event.preventDefault();
  if (!supabase) return renderLogin("Die Authentifizierung ist noch nicht konfiguriert.");

  const form = new FormData(event.currentTarget);
  const { data, error } = await supabase.auth.signInWithPassword({
    email: form.get("email"),
    password: form.get("password")
  });

  if (error) return renderLogin(error.message);

  await mountCountrySelection(data.user);
}

async function handleRegister(event) {
  event.preventDefault();
  if (!supabase) return renderRegister("Die Authentifizierung ist noch nicht konfiguriert.");

  const form = new FormData(event.currentTarget);
  const email = String(form.get("email") || "").trim();
  const profileName = String(form.get("profileName") || "").trim();
  const password = String(form.get("password") || "");
  const passwordConfirm = String(form.get("passwordConfirm") || "");

  if (password !== passwordConfirm) {
    return renderRegister("Die Passwörter stimmen nicht überein.");
  }

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        profile_name: profileName
      }
    }
  });

  if (error) return renderRegister(error.message);

  if (data.session?.user) {
    await mountCountrySelection(data.session.user);
    return;
  }

  renderLogin("Konto erstellt. Du kannst dich direkt mit deiner E-Mail-Adresse und deinem Passwort anmelden.");
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

renderEntry();
restoreExistingSession();
