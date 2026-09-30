import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "./auth-config-v2.js?v=20260930-2";

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
        </div>
      </section>
    </div>
  `;

  root.querySelector('[data-action="login"]').addEventListener("click", () => renderLogin());
  root.querySelector('[data-action="register"]').addEventListener("click", () => renderRegister());
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

async function mountCountrySelection(user) {
  root.hidden = true;
  const country = await import("../country/country.js?v=20260930-1");
  await country.mount(user);
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
