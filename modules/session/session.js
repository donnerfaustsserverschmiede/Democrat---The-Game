import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "../auth/auth-config-v2.js?v=20260930-4";

const root = document.querySelector("#session-app");
let supabase = null;
let currentUser = null;
let currentSessionId = null;
let currentPrefs = null;
let entry = null;
let factions = [];
let selectedFactionId = null;

const UI = {
  "de-DE": { intro:"Einführung", read:"Ich habe die Einführung gelesen – weiter", choose:"Fraktion wählen", existing:"Bestehende Fraktionen", new:"Neue Fraktion", name:"Fraktionsname", namePlaceholder:"Name der Fraktion", position:"Position im Plenum", left:"Links", center:"Mitte", right:"Rechts", members:"Mitglieder", seats:"Sitze", chooseExisting:"Diese Fraktion wählen", create:"Fraktion gründen und Sitz wählen", assigned:"Dein Sitz ist zugewiesen", assignedText:"Du sitzt in einem zusammenhängenden Fraktionsblock.", seat:"Sitz", back:"Zurück zur Sitzungsübersicht", loading:"Sitzung wird geladen …", error:"Die Sitzung konnte nicht geladen werden.", full:"Voll", selected:"Ausgewählt", required:"Bitte gib einen Fraktionsnamen ein und wähle eine Position.", factionFull:"Diese Fraktion hat bereits 10 Sitze.", sectorFull:"In diesem Sektor sind keine weiteren Fraktionsblöcke frei." },
  "es-ES": { intro:"Introducción", read:"He leído la introducción – continuar", choose:"Elegir grupo", existing:"Grupos existentes", new:"Nuevo grupo", name:"Nombre del grupo", namePlaceholder:"Nombre del grupo", position:"Posición en la cámara", left:"Izquierda", center:"Centro", right:"Derecha", members:"Miembros", seats:"Escaños", chooseExisting:"Elegir este grupo", create:"Crear grupo y elegir escaño", assigned:"Tu escaño está asignado", assignedText:"Te sientas en un bloque contiguo de tu grupo.", seat:"Escaño", back:"Volver al resumen", loading:"Cargando sesión …", error:"No se pudo cargar la sesión.", full:"Completo", selected:"Seleccionado", required:"Introduce un nombre y elige una posición.", factionFull:"Este grupo ya tiene 10 escaños.", sectorFull:"No quedan bloques libres en este sector." },
  "fr-FR": { intro:"Introduction", read:"J’ai lu l’introduction – continuer", choose:"Choisir un groupe", existing:"Groupes existants", new:"Nouveau groupe", name:"Nom du groupe", namePlaceholder:"Nom du groupe", position:"Position dans l’hémicycle", left:"Gauche", center:"Centre", right:"Droite", members:"Membres", seats:"Sièges", chooseExisting:"Choisir ce groupe", create:"Créer le groupe et choisir un siège", assigned:"Votre siège est attribué", assignedText:"Vous êtes placé dans un bloc contigu de votre groupe.", seat:"Siège", back:"Retour au résumé", loading:"Chargement de la session …", error:"Impossible de charger la session.", full:"Complet", selected:"Sélectionné", required:"Saisissez un nom et choisissez une position.", factionFull:"Ce groupe compte déjà 10 sièges.", sectorFull:"Aucun bloc libre dans ce secteur." },
  "it-IT": { intro:"Introduzione", read:"Ho letto l’introduzione – continua", choose:"Scegli il gruppo", existing:"Gruppi esistenti", new:"Nuovo gruppo", name:"Nome del gruppo", namePlaceholder:"Nome del gruppo", position:"Posizione in aula", left:"Sinistra", center:"Centro", right:"Destra", members:"Membri", seats:"Seggi", chooseExisting:"Scegli questo gruppo", create:"Crea gruppo e scegli il seggio", assigned:"Il tuo seggio è assegnato", assignedText:"Sei inserito in un blocco contiguo del tuo gruppo.", seat:"Seggio", back:"Torna al riepilogo", loading:"Caricamento sessione …", error:"Impossibile caricare la sessione.", full:"Completo", selected:"Selezionato", required:"Inserisci un nome e scegli una posizione.", factionFull:"Questo gruppo ha già 10 seggi.", sectorFull:"Non ci sono altri blocchi liberi in questo settore." },
  "pt-BR": { intro:"Introdução", read:"Li a introdução – continuar", choose:"Escolher bancada", existing:"Bancadas existentes", new:"Nova bancada", name:"Nome da bancada", namePlaceholder:"Nome da bancada", position:"Posição no plenário", left:"Esquerda", center:"Centro", right:"Direita", members:"Membros", seats:"Assentos", chooseExisting:"Escolher esta bancada", create:"Criar bancada e escolher assento", assigned:"Seu assento foi atribuído", assignedText:"Você está em um bloco contíguo da sua bancada.", seat:"Assento", back:"Voltar ao resumo", loading:"Carregando sessão …", error:"Não foi possível carregar a sessão.", full:"Lotada", selected:"Selecionada", required:"Digite um nome e escolha uma posição.", factionFull:"Esta bancada já tem 10 assentos.", sectorFull:"Não há mais blocos livres neste setor." },
  "en-US": { intro:"Introduction", read:"I have read the introduction – continue", choose:"Choose a faction", existing:"Existing factions", new:"New faction", name:"Faction name", namePlaceholder:"Faction name", position:"Position in the chamber", left:"Left", center:"Centre", right:"Right", members:"Members", seats:"Seats", chooseExisting:"Choose this faction", create:"Create faction and choose seat", assigned:"Your seat is assigned", assignedText:"You are placed in a contiguous faction block.", seat:"Seat", back:"Back to session overview", loading:"Loading session …", error:"The session could not be loaded.", full:"Full", selected:"Selected", required:"Enter a faction name and choose a position.", factionFull:"This faction already has 10 seats.", sectorFull:"No faction blocks are free in this sector." }
};
function t(){ return UI[currentPrefs?.locale] || UI["de-DE"]; }
function esc(v){return String(v??"").replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;").replaceAll("'","&#039;");}
function sideLabel(side){const x=t();return side==="left"?x.left:side==="center"?x.center:x.right;}

async function load(){
  root.hidden=false;
  root.innerHTML=`<div class="session-shell"><div class="session-loading">${t().loading}</div></div>`;
  const {data,error}=await supabase.rpc("get_session_entry",{p_session_id:currentSessionId});
  if(error||!data?.length){root.innerHTML=`<div class="session-shell"><div class="session-error">${t().error}</div></div>`;return;}
  entry=data[0];
  if(entry.read_confirmed){
    const {data:f,error:fe}=await supabase.rpc("get_session_factions",{p_session_id:currentSessionId});
    factions=fe?[]:(f||[]);
  }
  render();
}

function render(){
  const x=t();
  const assigned=entry.faction_id&&entry.seat_number;
  root.innerHTML=`
  <div class="session-shell">
    <header class="session-header">
      <div><div class="session-kicker">DEMOCRAT</div><h1>${esc(entry.display_name)}</h1><div class="session-chamber">${esc(entry.chamber_name)} · ${entry.player_count}/${entry.max_players}</div></div>
      <button class="session-back" type="button" data-back>×</button>
    </header>
    <main class="session-main">
      ${!entry.read_confirmed ? `
        <section class="session-panel session-intro">
          <div class="session-label">${x.intro}</div>
          <h2>${esc(entry.topic_title||entry.display_name)}</h2>
          <p>${esc(entry.topic_intro||"")}</p>
          <button class="session-primary" type="button" data-read>${x.read}</button>
        </section>`
      : assigned ? `
        <section class="session-panel session-assigned">
          <div class="session-label">${x.assigned}</div>
          <h2>${esc(entry.faction_name)}</h2>
          <p>${sideLabel(entry.faction_side)} · ${x.seat} <strong>${entry.seat_number}</strong></p>
          <div class="session-seat-note">${x.assignedText}</div>
          <button class="session-primary" type="button" data-back>${x.back}</button>
        </section>`
      : `
        <section class="session-panel">
          <div class="session-label">${x.choose}</div>
          <h2>${esc(entry.topic_title||entry.display_name)}</h2>
          <div class="faction-grid">
            ${factions.length ? factions.map(f=>`<button class="faction-card ${selectedFactionId===f.id?"selected":""}" data-faction="${f.id}" type="button"><strong>${esc(f.name)}</strong><span>${sideLabel(f.side)}</span><small>${f.member_count}/10 ${x.members}</small></button>`).join("") : `<div class="session-empty">${x.existing}: —</div>`}
          </div>
          <div class="new-faction">
            <h3>${x.new}</h3>
            <label>${x.name}<input id="faction-name" maxlength="40" placeholder="${x.namePlaceholder}"></label>
            <fieldset><legend>${x.position}</legend><div class="side-options">
              <label><input type="radio" name="side" value="left"> ${x.left}</label>
              <label><input type="radio" name="side" value="center" checked> ${x.center}</label>
              <label><input type="radio" name="side" value="right"> ${x.right}</label>
            </div></fieldset>
            <button class="session-primary" type="button" data-create>${x.create}</button>
            <div id="session-action-error" class="session-action-error" hidden></div>
          </div>
        </section>`}
    </main>
  </div>`;
  root.querySelectorAll("[data-back]").forEach(b=>b.addEventListener("click",()=>back()));
  const read=root.querySelector("[data-read]"); if(read) read.addEventListener("click",confirmRead);
  root.querySelectorAll("[data-faction]").forEach(b=>b.addEventListener("click",()=>{selectedFactionId=b.dataset.faction;render();}));
  const create=root.querySelector("[data-create]"); if(create) create.addEventListener("click",chooseNew);
}

async function confirmRead(){
  const {error}=await supabase.rpc("confirm_session_read",{p_session_id:currentSessionId});
  if(!error){await load();}
}

async function chooseNew(){
  const x=t(),name=root.querySelector("#faction-name")?.value.trim(),side=root.querySelector("input[name='side']:checked")?.value;
  const err=root.querySelector("#session-action-error");
  if(!name||!side){err.textContent=x.required;err.hidden=false;return;}
  const {data,error}=await supabase.rpc("choose_session_faction",{p_session_id:currentSessionId,p_faction_id:selectedFactionId,p_faction_name:selectedFactionId?null:name,p_side:selectedFactionId?null:side});
  if(error){err.textContent=error.message?.includes("faction_full")?x.factionFull:error.message?.includes("sector_full")?x.sectorFull:x.required;err.hidden=false;return;}
  selectedFactionId=null;await load();
}

function back(){
  root.hidden=true;root.innerHTML="";
  window.dispatchEvent(new CustomEvent("democrat:session-back"));
}
export async function mount(user,sessionId,prefs){
  if(!root)return;
  if(!SUPABASE_PUBLISHABLE_KEY||SUPABASE_PUBLISHABLE_KEY.startsWith("REPLACE_"))return;
  supabase=createClient(SUPABASE_URL,SUPABASE_PUBLISHABLE_KEY);currentUser=user;currentSessionId=sessionId;currentPrefs=prefs||{};await load();
}
export function unmount(){if(root){root.hidden=true;root.innerHTML="";}currentUser=null;currentSessionId=null;currentPrefs=null;entry=null;factions=[];selectedFactionId=null;}
