import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "../auth/auth-config-v2.js?v=20261001-5";
import * as sessionModule from "../session/session.js?v=20261001-34";
import * as playerModule from "../player/player.js?v=20261001-3";
import * as partyModule from "../party/party.js?v=20261001-3";

const root = document.querySelector("#overview-app");
const sessionRoot = document.querySelector("#session-app");
let supabase = null;
let currentUser = null;
let activeTab = "mine";
let currentPrefs = null;
let profileName = "Spieler";
let presenceTimer = null;
let presenceSessionIds = [];

const UI = {
  "de-DE": { title:"Übersicht", subtitle:"Wähle eine Sitzung, an der du teilnehmen möchtest.", mine:"MEINE SITZUNGEN", public:"ÖFFENTLICHE SITZUNGEN", refresh:"↻ Aktualisieren", loading:"Sitzungen werden geladen …", emptyMine:"Du nimmst aktuell an keiner Sitzung teil.", emptyPublic:"Aktuell sind keine öffentlichen Sitzungen verfügbar.", full:"Voll", open:"Offen", participating:"Teilnahme aktiv", joined:"Teilnehmend", openSession:"Sitzung öffnen", join:"Beitreten", seats:"Plätze belegt", country:"Land",sessionLimit:"Du kannst gleichzeitig an maximal 5 Sitzungen teilnehmen." },
  "de-AT": { title:"Übersicht", subtitle:"Wähle eine Sitzung, an der du teilnehmen möchtest.", mine:"MEINE SITZUNGEN", public:"ÖFFENTLICHE SITZUNGEN", refresh:"↻ Aktualisieren", loading:"Sitzungen werden geladen …", emptyMine:"Du nimmst aktuell an keiner Sitzung teil.", emptyPublic:"Aktuell sind keine öffentlichen Sitzungen verfügbar.", full:"Voll", open:"Offen", participating:"Teilnahme aktiv", joined:"Teilnehmend", openSession:"Sitzung öffnen", join:"Beitreten", seats:"Plätze belegt", country:"Land" },
  "de-CH": { title:"Übersicht", subtitle:"Wähle eine Sitzung, an der du teilnehmen möchtest.", mine:"MEINE SITZUNGEN", public:"ÖFFENTLICHE SITZUNGEN", refresh:"↻ Aktualisieren", loading:"Sitzungen werden geladen …", emptyMine:"Du nimmst aktuell an keiner Sitzung teil.", emptyPublic:"Aktuell sind keine öffentlichen Sitzungen verfügbar.", full:"Voll", open:"Offen", participating:"Teilnahme aktiv", joined:"Teilnehmend", openSession:"Sitzung öffnen", join:"Beitreten", seats:"Plätze belegt", country:"Land" },
  "es-ES": { title:"Resumen", subtitle:"Elige una sesión en la que quieras participar.", mine:"MIS SESIONES", public:"SESIONES PÚBLICAS", refresh:"↻ Actualizar", loading:"Cargando sesiones …", emptyMine:"Actualmente no participas en ninguna sesión.", emptyPublic:"No hay sesiones públicas disponibles.", full:"Completa", open:"Abierta", participating:"Participación activa", joined:"Participando", openSession:"Abrir sesión", join:"Unirse", seats:"plazas ocupadas", country:"País",sessionLimit:"Puedes participar simultáneamente en un máximo de 5 sesiones." },
  "es-MX": { title:"Resumen", subtitle:"Elige una sesión en la que quieras participar.", mine:"MIS SESIONES", public:"SESIONES PÚBLICAS", refresh:"↻ Actualizar", loading:"Cargando sesiones …", emptyMine:"Actualmente no participas en ninguna sesión.", emptyPublic:"No hay sesiones públicas disponibles.", full:"Llena", open:"Abierta", participating:"Participación activa", joined:"Participando", openSession:"Abrir sesión", join:"Unirse", seats:"plazas ocupadas", country:"País",sessionLimit:"Você pode participar de no máximo 5 sessões ao mesmo tempo." },
  "fr-FR": { title:"Aperçu", subtitle:"Choisissez une session à laquelle participer.", mine:"MES SESSIONS", public:"SESSIONS PUBLIQUES", refresh:"↻ Actualiser", loading:"Chargement des sessions …", emptyMine:"Vous ne participez actuellement à aucune session.", emptyPublic:"Aucune session publique disponible.", full:"Complète", open:"Ouverte", participating:"Participation active", joined:"Participant", openSession:"Ouvrir la session", join:"Rejoindre", seats:"places occupées", country:"Pays",sessionLimit:"Vous pouvez participer simultanément à 5 sessions maximum." },
  "it-IT": { title:"Panoramica", subtitle:"Scegli una sessione a cui partecipare.", mine:"LE MIE SESSIONI", public:"SESSIONI PUBBLICHE", refresh:"↻ Aggiorna", loading:"Caricamento delle sessioni …", emptyMine:"Non partecipi attualmente a nessuna sessione.", emptyPublic:"Nessuna sessione pubblica disponibile.", full:"Completa", open:"Aperta", participating:"Partecipazione attiva", joined:"Partecipante", openSession:"Apri sessione", join:"Partecipa", seats:"posti occupati", country:"Paese",sessionLimit:"Puoi partecipare contemporaneamente a un massimo di 5 sessioni." },
  "pt-BR": { title:"Visão geral", subtitle:"Escolha uma sessão da qual deseja participar.", mine:"MINHAS SESSÕES", public:"SESSÕES PÚBLICAS", refresh:"↻ Atualizar", loading:"Carregando sessões …", emptyMine:"Você não participa de nenhuma sessão.", emptyPublic:"Não há sessões públicas disponíveis.", full:"Lotada", open:"Aberta", participating:"Participação ativa", joined:"Participando", openSession:"Abrir sesión", join:"Entrar", seats:"lugares ocupados", country:"País" },
  "en-US": { title:"Overview", subtitle:"Choose a session you want to participate in.", mine:"MY SESSIONS", public:"PUBLIC SESSIONS", refresh:"↻ Refresh", loading:"Loading sessions …", emptyMine:"You are not currently participating in a session.", emptyPublic:"No public sessions are currently available.", full:"Full", open:"Open", participating:"Active participation", joined:"Participating", openSession:"Open session", join:"Join", seats:"seats occupied", country:"Country",sessionLimit:"You can participate in at most 5 sessions at the same time." },
  "en-GB": { title:"Overview", subtitle:"Choose a session you want to participate in.", mine:"MY SESSIONS", public:"PUBLIC SESSIONS", refresh:"↻ Refresh", loading:"Loading sessions …", emptyMine:"You are not currently participating in a session.", emptyPublic:"No public sessions are currently available.", full:"Full", open:"Open", participating:"Active participation", joined:"Participating", openSession:"Open session", join:"Join", seats:"seats occupied", country:"Country" },
  "en-CA": { title:"Overview", subtitle:"Choose a session you want to participate in.", mine:"MY SESSIONS", public:"PUBLIC SESSIONS", refresh:"↻ Refresh", loading:"Loading sessions …", emptyMine:"You are not currently participating in a session.", emptyPublic:"No public sessions are currently available.", full:"Full", open:"Open", participating:"Active participation", joined:"Participating", openSession:"Open session", join:"Join", seats:"seats occupied", country:"Country" },
  "en-AU": { title:"Overview", subtitle:"Choose a session you want to participate in.", mine:"MY SESSIONS", public:"PUBLIC SESSIONS", refresh:"↻ Refresh", loading:"Loading sessions …", emptyMine:"You are not currently participating in a session.", emptyPublic:"No public sessions are currently available.", full:"Full", open:"Open", participating:"Active participation", joined:"Participating", openSession:"Open session", join:"Join", seats:"seats occupied", country:"Country" }
};

function t() { return UI[currentPrefs?.locale] || UI["de-DE"]; }
function escapeHtml(value) { return String(value).replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;").replaceAll("'","&#039;"); }

function renderShell(profileName="Spieler") {
  const text=t();
  root.hidden=false;
  if(sessionRoot) sessionRoot.hidden=true;
  root.innerHTML=`
    <div class="overview-shell">
      <header class="overview-hud">
        <div class="overview-brand"><strong>DEMOCRAT</strong><span>The Game</span></div>
        <div class="overview-player"><span>${escapeHtml(currentPrefs?.display_name || "")}</span><br>${escapeHtml(profileName)}</div>
      </header>
      <main class="overview-main">
        <h1 class="overview-title">${text.title}</h1>
        <p class="overview-subtitle">${text.subtitle}</p>
        <div class="overview-tabs" role="tablist">
          <button class="overview-tab ${activeTab==="mine"?"active":""}" data-tab="mine" type="button">${text.mine}</button>
          <button class="overview-tab ${activeTab==="public"?"active":""}" data-tab="public" type="button">${text.public}</button>
          <button class="overview-refresh" data-action="refresh" type="button">${text.refresh}</button>
        </div>
        <section id="session-list" class="overview-list" aria-live="polite"></section>
      </main>
      <nav class="overview-bottom-nav" aria-label="Hauptmenü">
        <button class="overview-corner-button" data-action="party" type="button">♟ <span>Partei</span></button>
        <button class="overview-profile-button" data-action="profile" type="button">♙ <span>Profil</span></button>
        <button class="overview-corner-button" data-action="settings" type="button">⚙ <span>Einstellungen</span></button>
      </nav>
      <div id="overview-overlay" class="overview-overlay" hidden></div>
    </div>`;
  const overlay=root.querySelector("#overview-overlay");
  playerModule.init({client:supabase,user:currentUser,target:overlay});
  partyModule.init({client:supabase,user:currentUser,target:overlay});
  root.querySelectorAll("[data-tab]").forEach(button=>button.addEventListener("click",async()=>{activeTab=button.dataset.tab;renderShell(profileName);await loadSessions();}));
  root.querySelector("[data-action='refresh']").addEventListener("click",loadSessions);
  root.querySelector("[data-action='party']").addEventListener("click",()=>partyModule.open());
  root.querySelector("[data-action='profile']").addEventListener("click",()=>playerModule.open());
  root.querySelector("[data-action='settings']").addEventListener("click",openSettingsPanel);
}

function closeOverviewOverlay(){
  const overlay=root.querySelector("#overview-overlay");
  if(overlay){ overlay.hidden=true; overlay.innerHTML=""; }
}

function openSettingsPanel(){
  const overlay=root.querySelector("#overview-overlay");
  if(!overlay)return;
  const isGuest=Boolean(currentUser?.is_anonymous);
  const name=profileName || currentUser?.user_metadata?.profile_name || "Spieler";
  overlay.hidden=false;
  overlay.innerHTML=`<section class="overview-panel">
    <button class="overview-panel-close" data-close type="button">×</button>
    <h2>Einstellungen</h2>
    <p class="overview-panel-muted">Spieler: <strong>${escapeHtml(name)}</strong></p>
    ${isGuest ? `<div class="overview-settings-box">
      <h3>Gastkonto sichern</h3>
      <p>Verknüpfe eine E-Mail-Adresse und ein Passwort mit deinem bestehenden Gastkonto. Dein Spieler und dein kompletter Spielstand bleiben dabei erhalten.</p>
      <form id="guest-upgrade-form" class="overview-settings-form">
        <label>E-Mail<input name="email" type="email" autocomplete="email" required></label>
        <label>Passwort<input name="password" type="password" minlength="8" autocomplete="new-password" required></label>
        <label>Passwort bestätigen<input name="passwordConfirm" type="password" minlength="8" autocomplete="new-password" required></label>
        <div id="guest-upgrade-message" class="overview-settings-message" hidden></div>
        <button class="overview-settings-save" type="submit">Gastkonto in Account umwandeln</button>
      </form>
    </div>` : `<div class="overview-settings-box">
      <h3>Konto</h3><p>Dein Konto ist mit einer E-Mail-Adresse gesichert.</p>
      <p class="overview-panel-muted">${escapeHtml(currentUser?.email || "")}</p>
    </div>`}
  </section>`;
  overlay.querySelector("[data-close]").addEventListener("click",closeOverviewOverlay);
  const form=overlay.querySelector("#guest-upgrade-form");
  if(!form)return;
  form.addEventListener("submit",async(event)=>{
    event.preventDefault();
    const data=new FormData(form);
    const email=String(data.get("email")||"").trim();
    const password=String(data.get("password")||"");
    const confirm=String(data.get("passwordConfirm")||"");
    const message=overlay.querySelector("#guest-upgrade-message");
    const button=form.querySelector("button[type=submit]");
    if(password!==confirm){ message.hidden=false; message.textContent="Die Passwörter stimmen nicht überein."; return; }
    button.disabled=true; button.textContent="Wird gespeichert …"; message.hidden=true;
    try{
      const {data,error}=await supabase.auth.updateUser({
        email,
        password,
        data:{profile_name:name}
      });
      if(error) throw error;
      const {error:profileError}=await supabase.rpc("sync_profile_name",{p_profile_name:name});
      if(profileError) throw profileError;
      const user=data?.user;
      if(!user) throw new Error("Das Konto konnte nicht aktualisiert werden.");
      currentUser=user;
      profileName=user.user_metadata?.profile_name||profileName;
      message.hidden=false;
      message.className="overview-settings-message success";
      message.textContent="Dein Gastkonto wurde gesichert. Dein bestehender Spielstand bleibt erhalten.";
      button.remove();
    }catch(error){
      console.error("[Democrat] Guest account upgrade error:",error);
      message.hidden=false;
      message.className="overview-settings-message error";
      message.textContent=String(error?.message||"Das Konto konnte nicht gesichert werden.");
      button.disabled=false; button.textContent="Gastkonto in Account umwandeln";
    }
  });
}

async function updateSessionPresence() {
  if (!supabase || !currentUser || !presenceSessionIds.length) return;
  await supabase.rpc("touch_my_session_presence", { p_session_ids: presenceSessionIds });
}

async function loadSessions() {
  const list=root.querySelector("#session-list"); if(!list||!currentUser)return;
  const text=t(); list.innerHTML=`<div class="overview-empty">${text.loading}</div>`;
  const rpcName=activeTab==="mine"?"get_my_sessions":"get_public_sessions";
  const {data:sessions,error}=await supabase.rpc(rpcName);
  if(error){list.innerHTML=`<div class="overview-error">Sessions could not be loaded.</div>`;return;}
  const visible=sessions||[];
  if(activeTab==="mine"){
    presenceSessionIds=visible.map(s=>s.id);
  } else {
    const {data:mineSessions}=await supabase.rpc("get_my_sessions");
    presenceSessionIds=(mineSessions||[]).map(s=>s.id);
  }
  await updateSessionPresence();
  if(!visible.length){list.innerHTML=`<div class="overview-empty">${activeTab==="mine"?text.emptyMine:text.emptyPublic}</div>`;return;}
  list.innerHTML=visible.map(session=>{
    const full=session.player_count>=session.max_players;
    return `<article class="session-card">
      <div><h2 class="session-name">${escapeHtml(session.display_name)}</h2>
      <div class="session-meta">${session.player_count} / ${session.max_players} ${text.seats}</div>
      <span class="session-status">${full?text.full:text.open}${activeTab==="mine"?" · "+text.participating:""}</span></div>
      <button class="session-action" data-session-id="${session.id}" ${full&&activeTab==="public"?"disabled":""} type="button">${activeTab==="mine"?(session.read_confirmed&&session.seat_number?text.joined:text.openSession):full?text.full:text.join}</button>
    </article>`;
  }).join("");
  list.querySelectorAll("[data-session-id]").forEach(button=>button.addEventListener("click",()=>activeTab==="mine"?openSession(button.dataset.sessionId):joinSession(button.dataset.sessionId)));
}

function openSession(sessionId) {
  const text=t();
  if(!sessionRoot){
    root.hidden=false;
    root.innerHTML=`<div class="overview-main"><div class="overview-error"><strong>Sitzungsfenster fehlt.</strong><br><small>Das Element #session-app wurde nicht gefunden.</small></div></div>`;
    return;
  }

  // Switch immediately. Never leave the player on a blank/hidden screen.
  root.hidden=true;
  sessionRoot.hidden=false;
  sessionRoot.innerHTML=`
    <div class="session-shell">
      <div class="session-loading">
        <strong>Sitzung wird geladen …</strong>
        <span>${escapeHtml(sessionId)}</span>
      </div>
    </div>`;

  let loadFinished=false;
  const timeoutId=window.setTimeout(()=>{
    if(loadFinished)return;
    loadFinished=true;
    sessionRoot.hidden=false;
    sessionRoot.innerHTML=`
      <div class="session-shell">
        <div class="session-error">
          <strong>Sitzung konnte nicht geladen werden.</strong><br>
          <small>Der Ladevorgang hat zu lange gedauert.</small><br>
          <button class="session-secondary" type="button" data-session-retry>Erneut versuchen</button>
          <button class="session-secondary" type="button" data-session-back>Zurück</button>
        </div>
      </div>`;
    sessionRoot.querySelector("[data-session-retry]")?.addEventListener("click",()=>openSession(sessionId));
    sessionRoot.querySelector("[data-session-back]")?.addEventListener("click",()=>{
      sessionRoot.hidden=true;
      sessionRoot.innerHTML="";
      root.hidden=false;
      renderShell(profileName);
      loadSessions();
    });
  },15000);

  Promise.resolve()
    .then(()=>sessionModule.mount(currentUser,sessionId,currentPrefs))
    .then(()=>{
      if(loadFinished)return;
      loadFinished=true;
      window.clearTimeout(timeoutId);
      sessionRoot.hidden=false;
    })
    .catch(error=>{
      if(loadFinished)return;
      loadFinished=true;
      window.clearTimeout(timeoutId);
      console.error("[Democrat] Failed to open session:",error);
      sessionRoot.hidden=false;
      sessionRoot.innerHTML=`
        <div class="session-shell">
          <div class="session-error">
            <strong>Sitzung konnte nicht geöffnet werden.</strong><br>
            <small>${escapeHtml(error?.stack||error?.message||String(error))}</small><br>
            <button class="session-secondary" type="button" data-session-retry>Erneut versuchen</button>
            <button class="session-secondary" type="button" data-session-back>Zurück</button>
          </div>
        </div>`;
      sessionRoot.querySelector("[data-session-retry]")?.addEventListener("click",()=>openSession(sessionId));
      sessionRoot.querySelector("[data-session-back]")?.addEventListener("click",()=>{
        sessionRoot.hidden=true;
        sessionRoot.innerHTML="";
        root.hidden=false;
        renderShell(profileName);
        loadSessions();
      });
    });
}
async function joinSession(sessionId) {
  root.querySelectorAll("[data-session-id]").forEach(button=>button.disabled=true);
  const {error}=await supabase.rpc("join_session",{p_session_id:sessionId});
  if(error){if(error.message?.includes("session_limit_reached")) alert(t().sessionLimit||"Du kannst gleichzeitig an maximal 5 Sitzungen teilnehmen."); await loadSessions();return;}
  activeTab="mine";
  await openSession(sessionId);
}

export async function mount(user,prefs=null) {
  if(!root)return;
  if(!SUPABASE_PUBLISHABLE_KEY||SUPABASE_PUBLISHABLE_KEY.startsWith("REPLACE_")){root.hidden=false;root.innerHTML=`<div class="overview-main"><div class="overview-error">Supabase configuration is missing.</div></div>`;return;}
  supabase=createClient(SUPABASE_URL,SUPABASE_PUBLISHABLE_KEY); currentUser=user;
  if(!prefs){const {data}=await supabase.rpc("get_country_preferences");prefs=data?.[0]||null;}
  if(!prefs?.country_code){root.hidden=false;root.innerHTML=`<div class="overview-main"><div class="overview-error">Bitte zuerst ein Land auswählen.</div></div>`;return;}
  currentPrefs=prefs;
  profileName=user.user_metadata?.profile_name||user.email||"Spieler";
  const overlay=root.querySelector("#overview-overlay");
  renderShell(profileName); await loadSessions();
  if (presenceTimer) clearInterval(presenceTimer);
  presenceTimer = setInterval(updateSessionPresence, 20000);
}

window.addEventListener("democrat:session-back",()=>{root.hidden=false;renderShell(profileName);loadSessions();});

export function unmount(){if(presenceTimer)clearInterval(presenceTimer);presenceTimer=null;presenceSessionIds=[];if(!root)return;root.hidden=true;root.innerHTML="";if(sessionRoot)sessionRoot.hidden=true;currentUser=null;currentPrefs=null;profileName="Spieler";}

// cache-version: 20261001-38
