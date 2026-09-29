import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "./auth-config.js";

const root = document.querySelector("#auth-app");

let supabase = null;
if (!SUPABASE_PUBLISHABLE_KEY.startsWith("REPLACE_")) {
  supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
}

async function openOverview(user) {
  root.hidden = true;
  const overviewRoot = document.querySelector("#overview-app");
  if (overviewRoot) overviewRoot.hidden = false;

  const { mount } = await import("../overview/overview.js");
  await mount(user);
}

function renderEntry() {
  root.hidden = false;
  root.innerHTML = `
    <div class="auth-shell">
      <section class="auth-card">
        <div class="auth-brand">
          <div class="auth-mark">D</div>
          <h1>Democrat</h1>
          <p>The Game</p>
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
  root.hidden = false;
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
  root.hidden = false;
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

async function handleLogin(event) {
  event.preventDefault();
  if (!supabase) return renderLogin("Die Authentifizierung ist noch nicht konfiguriert.");

  const form = new FormData(event.currentTarget);
  const { data, error } = await supabase.auth.signInWithPassword({
    email: form.get("email"),
    password: form.get("password")
  });

  if (error) return renderLogin(error.message);
  await openOverview(data.user);
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
    options: { data: { profile_name: profileName } }
  });

  if (error) return renderRegister(error.message);

  if (data.session && data.user) {
    await openOverview(data.user);
    return;
  }

  renderLogin("Konto erstellt. Falls eine E-Mail-Bestätigung aktiviert ist, bestätige zuerst deine E-Mail-Adresse.");
}

async function restoreExistingSession() {
  if (!supabase) {
    renderEntry();
    return;
  }

  const { data } = await supabase.auth.getSession();
  if (data.session?.user) {
    await openOverview(data.session.user);
    return;
  }

  renderEntry();
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

restoreExistingSession();
