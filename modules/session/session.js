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
let seats = [];
let switchingFaction = false;
let factionManagement = [];

const UI = {
  "de-DE": { intro:"Einführung", read:"Ich habe die Einführung gelesen – weiter", choose:"Fraktion wählen", existing:"Bestehende Fraktionen", new:"Neue Fraktion", name:"Fraktionsname", namePlaceholder:"Name der Fraktion", position:"Position im Plenum", left:"Links", center:"Mitte", right:"Rechts", members:"Mitglieder", seats:"Sitze", chooseExisting:"Diese Fraktion wählen", create:"Fraktion gründen und Sitz wählen", assigned:"Dein Sitz ist zugewiesen", assignedText:"Du sitzt in einem zusammenhängenden Fraktionsblock.", seat:"Sitz", back:"Zurück zur Sitzungsübersicht", changeFaction:"Fraktion wechseln", cancel:"Abbrechen", loading:"Sitzung wird geladen …", error:"Die Sitzung konnte nicht geladen werden.", full:"Voll", selected:"Ausgewählt", required:"Bitte gib einen Fraktionsnamen ein und wähle eine Position.", factionFull:"Diese Fraktion hat bereits 10 Sitze.", sectorFull:"In diesem Sektor sind keine weiteren Fraktionsblöcke frei.", management:"Fraktionsverwaltung", leader:"Fraktionsvorsitz", deputy:"Stellvertretender Vorsitz", promote:"Zum Stellvertreter ernennen", removeDeputy:"Stellvertretung aufheben", kick:"Aus Fraktion entfernen", deleteFaction:"Fraktion löschen", deleteConfirm:"Fraktion wirklich löschen? Alle Mitglieder verlieren ihre Fraktionszugehörigkeit.", kickConfirm:"Mitglied wirklich aus der Fraktion entfernen?" , actions:"Fraktionsaktionen",actionHint:"Aktionen können zusätzliche leere Fraktionsplätze sichern. Besetzte Plätze werden niemals verdrängt.",speech:"Fraktionsrede · +1 Sitz",committee:"Ausschussarbeit · +2 Sitze",publicity:"Öffentlichkeitsarbeit · +3 Sitze",actionError:"Aktion konnte nicht ausgeführt werden."},
  "es-ES": { intro:"Introducción", read:"He leído la introducción – continuar", choose:"Elegir grupo", existing:"Grupos existentes", new:"Nuevo grupo", name:"Nombre del grupo", namePlaceholder:"Nombre del grupo", position:"Posición en la cámara", left:"Izquierda", center:"Centro", right:"Derecha", members:"Miembros", seats:"Escaños", chooseExisting:"Elegir este grupo", create:"Crear grupo y elegir escaño", assigned:"Tu escaño está asignado", assignedText:"Te sientas en un bloque contiguo de tu grupo.", seat:"Escaño", back:"Volver al resumen", changeFaction:"Cambiar de grupo", cancel:"Cancelar", loading:"Cargando sesión …", error:"No se pudo cargar la sesión.", full:"Completo", selected:"Seleccionado", required:"Introduce un nombre y elige una posición.", factionFull:"Este grupo ya tiene 10 escaños.", sectorFull:"No quedan bloques libres en este sector." , actions:"Acciones del grupo",actionHint:"Las acciones pueden asegurar escaños vacíos adicionales. Los jugadores existentes nunca son desplazados.",speech:"Discurso del grupo · +1 escaño",committee:"Trabajo en comisión · +2 escaños",publicity:"Comunicación pública · +3 escaños",actionError:"No se pudo ejecutar la acción."},
  "fr-FR": { intro:"Introduction", read:"J’ai lu l’introduction – continuer", choose:"Choisir un groupe", existing:"Groupes existants", new:"Nouveau groupe", name:"Nom du groupe", namePlaceholder:"Nom du groupe", position:"Position dans l’hémicycle", left:"Gauche", center:"Centre", right:"Droite", members:"Membres", seats:"Sièges", chooseExisting:"Choisir ce groupe", create:"Créer le groupe et choisir un siège", assigned:"Votre siège est attribué", assignedText:"Vous êtes placé dans un bloc contigu de votre groupe.", seat:"Siège", back:"Retour au résumé", changeFaction:"Changer de groupe", cancel:"Annuler", loading:"Chargement de la session …", error:"Impossible de charger la session.", full:"Complet", selected:"Sélectionné", required:"Saisissez un nom et choisissez une position.", factionFull:"Ce groupe compte déjà 10 sièges.", sectorFull:"Aucun bloc libre dans ce secteur." , actions:"Actions du groupe",actionHint:"Les actions peuvent sécuriser des sièges vides supplémentaires. Aucun joueur en place n’est déplacé.",speech:"Discours du groupe · +1 siège",committee:"Travail en commission · +2 sièges",publicity:"Action publique · +3 sièges",actionError:"L’action n’a pas pu être exécutée."},
  "it-IT": { intro:"Introduzione", read:"Ho letto l’introduzione – continua", choose:"Scegli il gruppo", existing:"Gruppi esistenti", new:"Nuovo gruppo", name:"Nome del gruppo", namePlaceholder:"Nome del gruppo", position:"Posizione in aula", left:"Sinistra", center:"Centro", right:"Destra", members:"Membri", seats:"Seggi", chooseExisting:"Scegli questo gruppo", create:"Crea gruppo e scegli il seggio", assigned:"Il tuo seggio è assegnato", assignedText:"Sei inserito in un blocco contiguo del tuo gruppo.", seat:"Seggio", back:"Torna al riepilogo", changeFaction:"Cambia gruppo", cancel:"Annulla", loading:"Caricamento sessione …", error:"Impossibile caricare la sessione.", full:"Completo", selected:"Selezionato", required:"Inserisci un nome e scegli una posizione.", factionFull:"Questo gruppo ha già 10 seggi.", sectorFull:"Non ci sono altri blocchi liberi in questo settore." , actions:"Azioni del gruppo",actionHint:"Le azioni possono assicurare ulteriori seggi liberi. Nessun giocatore già seduto viene spostato.",speech:"Intervento del gruppo · +1 seggio",committee:"Lavoro in commissione · +2 seggi",publicity:"Azione pubblica · +3 seggi",actionError:"Impossibile eseguire l’azione."},
  "pt-BR": { intro:"Introdução", read:"Li a introdução – continuar", choose:"Escolher bancada", existing:"Bancadas existentes", new:"Nova bancada", name:"Nome da bancada", namePlaceholder:"Nome da bancada", position:"Posição no plenário", left:"Esquerda", center:"Centro", right:"Direita", members:"Membros", seats:"Assentos", chooseExisting:"Escolher esta bancada", create:"Criar bancada e escolher assento", assigned:"Seu assento foi atribuído", assignedText:"Você está em um bloco contíguo da sua bancada.", seat:"Assento", back:"Voltar ao resumo", changeFaction:"Trocar de bancada", cancel:"Cancelar", loading:"Carregando sessão …", error:"Não foi possível carregar a sessão.", full:"Lotada", selected:"Selecionada", required:"Digite um nome e escolha uma posição.", factionFull:"Esta bancada já tem 10 assentos.", sectorFull:"Não há mais blocos livres neste setor." , actions:"Ações da bancada",actionHint:"As ações podem garantir assentos vazios adicionais. Nenhum jogador já sentado é deslocado.",speech:"Discurso da bancada · +1 assento",committee:"Trabalho em comissão · +2 assentos",publicity:"Ação pública · +3 assentos",actionError:"Não foi possível executar a ação."},
  "en-US": { intro:"Introduction", read:"I have read the introduction – continue", choose:"Choose a faction", existing:"Existing factions", new:"New faction", name:"Faction name", namePlaceholder:"Faction name", position:"Position in the chamber", left:"Left", center:"Centre", right:"Right", members:"Members", seats:"Seats", chooseExisting:"Choose this faction", create:"Create faction and choose seat", assigned:"Your seat is assigned", assignedText:"You are placed in a contiguous faction block.", seat:"Seat", back:"Back to session overview", changeFaction:"Change faction", cancel:"Cancel", loading:"Loading session …", error:"The session could not be loaded.", full:"Full", selected:"Selected", required:"Enter a faction name and choose a position.", factionFull:"This faction already has 10 seats.", sectorFull:"No faction blocks are free in this sector.", management:"Faction management", leader:"Faction chair", deputy:"Deputy chair", promote:"Appoint deputy", removeDeputy:"Remove deputy", kick:"Remove from faction", deleteFaction:"Delete faction", deleteConfirm:"Delete this faction? All members will lose faction membership.", kickConfirm:"Remove this member from the faction?" }
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
    const [{data:f,error:fe, actions:"Faction actions",actionHint:"Actions can secure additional empty faction seats. Players already seated are never displaced.",speech:"Faction speech · +1 seat",committee:"Committee work · +2 seats",publicity:"Public outreach · +3 seats",actionError:"The action could not be executed."},{data:s,error:se}]=await Promise.all([
      supabase.rpc("get_session_factions",{p_session_id:currentSessionId}),
      supabase.rpc("get_session_seats",{p_session_id:currentSessionId})
    ]);
    factions=fe?[]:(f||[]);
    seats=se?[]:(s||[]);
    const {data:fm}=await supabase.rpc("get_session_faction_management",{p_session_id:currentSessionId});
    factionManagement=fm||[];
  }
  render();
}

function renderChamber(){
  const playerId=currentUser?.id;
  const seatMarkup=seats.map((seat,index)=>{
    const row=Math.floor(index/10);
    const col=index%10;
    const radii=[47,42,37,32,27,22];
    const angles=[165,148.3,131.7,115,98.3,81.7,65,48.3,31.7,15];
    const angle=angles[col]*Math.PI/180;
    const xPos=50+Math.cos(angle)*radii[row];
    const yPos=30+Math.sin(angle)*radii[row]*0.72;
    const occupied=Boolean(seat.user_id);
    const controlled=Boolean(seat.faction_id)&&!occupied;
    const own=seat.user_id===playerId;
    const colorClass=seat.faction_color ? " faction-"+esc(seat.faction_color) : "";
    const cls=own ? "seat own-seat" : occupied ? "seat occupied-seat"+colorClass : controlled ? "seat controlled-empty-seat"+colorClass : "seat";
    const label=own ? "Du" : occupied ? esc(seat.profile_name) : "";
    const title=occupied
      ? esc(seat.profile_name)+" · "+esc(seat.faction_name||"")
      : controlled
        ? "Fraktionsplatz · "+esc(seat.faction_name||"")
        : "Freier Sitz";
    return `<div class="${cls}" style="--x:${xPos}%;--y:${yPos}%" title="${title}"><span class="seat-dot"></span>${label ? `<span class="seat-label">${label}</span>` : ""}</div>`;
  }).join("");
  return `<div class="chamber-wrap">
    <div class="chamber-title">Sitzungsplenum · 60 Sitze</div>
    <div class="chamber-map hemicycle-map">
      <div class="presidium"><span>PRÄSIDIUM</span><small>Präsident / Präsidium</small></div>
      <div class="hemicycle-floor"></div>
      <div class="chamber-seats">${seatMarkup}</div>
    </div>
    <div class="chamber-legend">${factions.map(f=>`<span><i class="legend-dot faction-${esc(f.color_code||"blue")}"></i>${esc(f.name)}</span>`).join("")}</div>
  </div>`;
}
function renderSideOptions(x){
  const counts={left:0,center:0,right:0};
  seats.forEach(s=>{if(s.faction_id)counts[s.side]=(counts[s.side]||0)+1;});
  return ["left","center","right"].map(side=>{
    const full=counts[side]>=20;
    return '<label class="'+(full?'side-disabled':'')+'"><input type="radio" name="side" value="'+side+'" '+(side==='center'&&!full?'checked ':'')+(full?'disabled':'')+'> '+sideLabel(side)+(full?' · '+x.full:'')+'</label>';
  }).join('');
}
function renderFactionChooser(x){
  const counts={left:0,center:0,right:0};
  seats.forEach(s=>{if(s.faction_id)counts[s.side]=(counts[s.side]||0)+1;});
  const sideFull=side=>counts[side]>=20;
  let html="<div class=\"faction-switch\"><h3>"+x.choose+"</h3><div class=\"faction-grid\">";
  if(factions.length){
    factions.forEach(f=>{html+="<button class=\"faction-card "+(selectedFactionId===f.id?"selected":"")+" \" data-faction=\""+f.id+"\" type=\"button\"><strong><i class=\"faction-swatch faction-"+esc(f.color_code||"blue")+"\"></i>"+esc(f.name)+"</strong><span>"+sideLabel(f.side)+"</span><small>"+f.member_count+"/10 "+x.members+"</small></button>";});
  }else html+="<div class=\"session-empty\">"+x.existing+": —</div>";
  html+="</div>";
  if(selectedFactionId)html+="<button class=\"session-primary faction-confirm\" type=\"button\" data-existing>"+x.chooseExisting+"</button>";
  html+="<div class=\"new-faction\"><h3>"+x.new+"</h3><label>"+x.name+"<input id=\"faction-name\" maxlength=\"40\" placeholder=\""+x.namePlaceholder+"\"></label><fieldset><legend>"+x.position+"</legend><div class=\"side-options\">";
  html+=renderSideOptions(x);
  html+="</div></fieldset><button class=\"session-primary\" type=\"button\" data-create>"+x.create+"</button><div id=\"session-action-error\" class=\"session-action-error\" hidden></div></div></div>";
  return html;
}
function renderFactionActions(){
  const x=t();
  return `<div class="faction-actions">
    <h3>${x.actions}</h3>
    <p>${x.actionHint}</p>
    <div class="faction-action-grid">
      <button type="button" class="session-secondary faction-action" data-action="fraktionsrede">${x.speech}</button>
      <button type="button" class="session-secondary faction-action" data-action="ausschussarbeit">${x.committee}</button>
      <button type="button" class="session-secondary faction-action" data-action="oeffentlichkeitsarbeit">${x.publicity}</button>
    </div>
    <div id="faction-action-error" class="session-action-error" hidden></div>
  </div>`;
}
async function performFactionAction(code){
  const box=root.querySelector("#faction-action-error");
  const {error}=await supabase.rpc("perform_faction_action",{p_session_id:currentSessionId,p_action_code:code});
  if(error){
    if(box){box.hidden=false;box.textContent=t().actionError;}
    return;
  }
  await load();
}
function renderFactionManagement(){
  const x=t(), rows=factionManagement.filter(m=>m.faction_id===entry.faction_id);
  if(!rows.length)return "";
  const leaderId=rows[0].leader_user_id, deputyId=rows[0].deputy_user_id, uid=currentUser?.id;
  if(uid!==leaderId&&uid!==deputyId)return "";
  let html="<div class=\"faction-management\"><h3>"+x.management+"</h3>";
  rows.forEach(m=>{
    const role=m.user_id===leaderId?x.leader:(m.user_id===deputyId?x.deputy:"Sitz "+m.seat_number);
    html+="<div class=\"management-member\"><div><strong>"+esc(m.profile_name||"Spieler")+"</strong><span>"+role+"</span></div>";
    if(m.user_id!==leaderId){
      html+="<div class=\"management-actions\">";
      if(m.user_id===deputyId) html+="<button type=\"button\" class=\"session-secondary management-action\" data-remove-deputy>"+x.removeDeputy+"</button>";
      else html+="<button type=\"button\" class=\"session-secondary management-action\" data-promote=\""+m.user_id+"\">"+x.promote+"</button>";
      html+="<button type=\"button\" class=\"session-danger management-action\" data-kick=\""+m.user_id+"\">"+x.kick+"</button></div>";
    }
    html+="</div>";
  });
  html+="<button type=\"button\" class=\"session-danger management-delete\" data-delete-faction>"+x.deleteFaction+"</button></div>";
  return html;
}
async function factionAction(kind,id){
  let result;
  if(kind==="delete"){if(!confirm(t().deleteConfirm))return;result=await supabase.rpc("delete_session_faction",{p_faction_id:entry.faction_id});}
  if(kind==="kick"){if(!confirm(t().kickConfirm))return;result=await supabase.rpc("kick_session_faction_member",{p_faction_id:entry.faction_id,p_member_id:id});}
  if(kind==="promote")result=await supabase.rpc("set_session_faction_deputy",{p_faction_id:entry.faction_id,p_member_id:id});
  if(kind==="remove")result=await supabase.rpc("remove_session_faction_deputy",{p_faction_id:entry.faction_id});
  if(result?.error){alert(result.error.message);return;}
  await load();
}
function render(){
  const x=t();
  const assigned=entry.faction_id&&entry.seat_number;
  root.innerHTML=`
  <div class="session-shell">
    <header class="session-header">
      <div><img class="game-logo session-logo" src="./assets/democrat-logo.svg" alt="Democrat – The Game"><h1>${esc(entry.display_name)}</h1><div class="session-chamber">${esc(entry.chamber_name)} · ${entry.player_count}/${entry.max_players}</div></div>
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
          ${renderChamber()}
          ${renderFactionActions()}${renderFactionManagement()}${switchingFaction ? renderFactionChooser(x) : `<button class="session-primary" type="button" data-switch>${x.changeFaction}</button>`}
          ${switchingFaction ? `<button class="session-secondary" type="button" data-cancel-switch>${x.cancel}</button>` : ""}
        </section>`
      : `
        <section class="session-panel">
          <div class="session-label">${x.choose}</div>
          <h2>${esc(entry.topic_title||entry.display_name)}</h2>
          <div class="faction-grid">
            ${factions.length ? factions.map(f=>`<button class="faction-card ${selectedFactionId===f.id?"selected":""}" data-faction="${f.id}" type="button"><strong>${esc(f.name)}</strong><span>${sideLabel(f.side)}</span><small>${f.member_count}/10 ${x.members}</small></button>`).join("") : `<div class="session-empty">${x.existing}: —</div>`}
          </div>
          ${selectedFactionId ? `<button class="session-primary faction-confirm" type="button" data-existing>${x.chooseExisting}</button>` : ""}
          <div class="new-faction">
            <h3>${x.new}</h3>
            <label>${x.name}<input id="faction-name" maxlength="40" placeholder="${x.namePlaceholder}"></label>
            <fieldset><legend>${x.position}</legend><div class="side-options">${renderSideOptions(x)}</div></fieldset>
            <button class="session-primary" type="button" data-create>${x.create}</button>
            <div id="session-action-error" class="session-action-error" hidden></div>
          </div>
        </section>`}
    </main>
  </div>`;
  root.querySelectorAll("[data-back]").forEach(b=>b.addEventListener("click",()=>back()));
  const sw=root.querySelector("[data-switch]"); if(sw) sw.addEventListener("click",()=>{switchingFaction=true;render();});
  const cs=root.querySelector("[data-cancel-switch]"); if(cs) cs.addEventListener("click",()=>{switchingFaction=false;selectedFactionId=null;render();});
  const read=root.querySelector("[data-read]"); if(read) read.addEventListener("click",confirmRead);
  root.querySelectorAll("[data-faction]").forEach(b=>b.addEventListener("click",()=>{selectedFactionId=b.dataset.faction;render();}));
  const create=root.querySelector("[data-create]"); if(create) create.addEventListener("click",chooseNew);
  const existing=root.querySelector("[data-existing]"); if(existing) existing.addEventListener("click",chooseExisting);
  root.querySelectorAll("[data-action]").forEach(b=>b.addEventListener("click",()=>performFactionAction(b.dataset.action)));\n  root.querySelectorAll("[data-kick]").forEach(b=>b.addEventListener("click",()=>factionAction("kick",b.dataset.kick)));
  root.querySelectorAll("[data-promote]").forEach(b=>b.addEventListener("click",()=>factionAction("promote",b.dataset.promote)));
  const rd=root.querySelector("[data-remove-deputy]"); if(rd) rd.addEventListener("click",()=>factionAction("remove"));
  const df=root.querySelector("[data-delete-faction]"); if(df) df.addEventListener("click",()=>factionAction("delete"));
}

async function confirmRead(){
  const {error}=await supabase.rpc("confirm_session_read",{p_session_id:currentSessionId});
  if(!error){await load();}
}

function mapFactionError(error){
  const code=error?.code||"";
  const msg=error?.message||"";
  if(code==="faction_full"||msg.includes("faction_full"))return t().factionFull;
  if(code==="sector_full"||msg.includes("sector_full"))return t().sectorFull;
  if(code==="faction_name_required"||msg.includes("faction_name_required"))return t().required;
  if(code==="faction_side_required"||msg.includes("faction_side_required"))return t().required;
  if(code==="session_read_required"||msg.includes("session_read_required"))return t().read;
  return msg||t().required;
}
async function chooseExisting(){
  if(!selectedFactionId)return;
  const err=root.querySelector("#session-action-error");
  const {error}=await supabase.rpc("choose_session_faction",{p_session_id:currentSessionId,p_faction_id:selectedFactionId,p_faction_name:null,p_side:null});
  if(error){err.textContent=mapFactionError(error);err.hidden=false;return;}
  selectedFactionId=null;switchingFaction=false;await load();
}

async function chooseNew(){
  const x=t(),name=root.querySelector("#faction-name")?.value.trim(),side=root.querySelector("input[name='side']:checked")?.value;
  const err=root.querySelector("#session-action-error");
  if(!name||!side){err.textContent=x.required;err.hidden=false;return;}
  const {data,error}=await supabase.rpc("choose_session_faction",{p_session_id:currentSessionId,p_faction_id:selectedFactionId,p_faction_name:selectedFactionId?null:name,p_side:selectedFactionId?null:side});
  if(error){err.textContent=mapFactionError(error);err.hidden=false;return;}
  selectedFactionId=null;switchingFaction=false;await load();
}

function back(){
  root.hidden=true;root.innerHTML="";
  window.dispatchEvent(new CustomEvent("democrat:session-back"));
}
export async function mount(user,sessionId,prefs){
  if(!root)return;
  root.hidden=false;
  if(!SUPABASE_PUBLISHABLE_KEY||SUPABASE_PUBLISHABLE_KEY.startsWith("REPLACE_"))return;
  supabase=createClient(SUPABASE_URL,SUPABASE_PUBLISHABLE_KEY);currentUser=user;currentSessionId=sessionId;currentPrefs=prefs||{};selectedFactionId=null;switchingFaction=false;await load();
}
export function unmount(){if(root){root.hidden=true;root.innerHTML="";}currentUser=null;currentSessionId=null;currentPrefs=null;entry=null;factions=[];seats=[];factionManagement=[];selectedFactionId=null;switchingFaction=false;}
