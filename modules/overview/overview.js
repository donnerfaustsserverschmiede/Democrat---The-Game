import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "../auth/auth-config.js";

const root = document.querySelector("#overview-app");

let supabase = null;
let currentUser = null;
let activeTab = "mine";

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function renderShell(profileName = "Spieler") {
  root.hidden = false;
  root.innerHTML = `
    <div class="overview-shell">
      <header class="overview-hud">
        <div class="overview-brand">
          <strong>DEMOCRAT</strong>
          <span>The Game</span>
        </div>
        <div class="overview-player">${escapeHtml(profileName)}</div>
      </header>

      <main class="overview-main">
        <h1 class="overview-title">Übersicht</h1>
        <p class="overview-subtitle">Wähle eine Sitzung, an der du teilnehmen möchtest.</p>

        <div class="overview-tabs" role="tablist">
          <button class="overview-tab ${activeTab === "mine" ? "active" : ""}" data-tab="mine" type="button">MEINE SITZUNGEN</button>
          <button class="overview-tab ${activeTab === "public" ? "active" : ""}" data-tab="public" type="button">ÖFFENTLICHE SITZUNGEN</button>
          <button class="overview-refresh" data-action="refresh" type="button">↻ Aktualisieren</button>
        </div>

        <section id="session-list" class="overview-list" aria-live="polite"></section>
      </main>
    </div>
  `;

  root.querySelectorAll("[data-tab]").forEach(button => {
    button.addEventListener("click", async () => {
      activeTab = button.dataset.tab;
      renderShell(profileName);
      await loadSessions();
    });
  });

  root.querySelector("[data-action='refresh']").addEventListener("click", loadSessions);
}

async function loadSessions() {
  const list = root.querySelector("#session-list");
  if (!list || !currentUser) return;

  list.innerHTML = `<div class="overview-empty">Sitzungen werden geladen …</div>`;

  const rpcName = activeTab === "mine" ? "get_my_sessions" : "get_public_sessions";
  const { data: sessions, error } = await supabase.rpc(rpcName);

  if (error) {
    list.innerHTML = `<div class="overview-error">Sitzungen konnten nicht geladen werden.</div>`;
    return;
  }

  const visible = sessions || [];

  if (!visible.length) {
    list.innerHTML = `<div class="overview-empty">${activeTab === "mine"
      ? "Du nimmst aktuell an keiner Sitzung teil."
      : "Aktuell sind keine öffentlichen Sitzungen verfügbar."
    }</div>`;
    return;
  }

  list.innerHTML = visible.map(session => {
    const full = session.player_count >= session.max_players;

    return `
      <article class="session-card">
        <div>
          <h2 class="session-name">${escapeHtml(session.display_name)}</h2>
          <div class="session-meta">${session.player_count} / ${session.max_players} Plätze belegt</div>
          <span class="session-status">${full ? "Voll" : "Offen"}${activeTab === "mine" ? " · Teilnahme aktiv" : ""}</span>
        </div>

        <button class="session-action" data-session-id="${session.id}"
          ${activeTab === "mine" || full ? "disabled" : ""} type="button">
          ${activeTab === "mine" ? "Teilnehmend" : full ? "Voll" : "Beitreten"}
        </button>
      </article>
    `;
  }).join("");

  list.querySelectorAll("[data-session-id]").forEach(button => {
    button.addEventListener("click", () => joinSession(button.dataset.sessionId));
  });
}

async function joinSession(sessionId) {
  const buttons = root.querySelectorAll("[data-session-id]");
  buttons.forEach(button => button.disabled = true);

  const { error } = await supabase.rpc("join_session", { p_session_id: sessionId });

  if (error) {
    await loadSessions();
    return;
  }

  activeTab = "mine";
  const profileName = root.querySelector(".overview-player")?.textContent || "Spieler";
  renderShell(profileName);
  await loadSessions();
}

export async function mount(user) {
  if (!root) return;

  if (!SUPABASE_PUBLISHABLE_KEY || SUPABASE_PUBLISHABLE_KEY.startsWith("REPLACE_")) {
    root.hidden = false;
    root.innerHTML = `<div class="overview-main"><div class="overview-error">Die Supabase-Publishable-Key-Konfiguration fehlt.</div></div>`;
    return;
  }

  supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
  currentUser = user;

  const profileName = user.user_metadata?.profile_name || user.email || "Spieler";
  renderShell(profileName);
  await loadSessions();
}

export function unmount() {
  if (!root) return;
  root.hidden = true;
  root.innerHTML = "";
  currentUser = null;
}
