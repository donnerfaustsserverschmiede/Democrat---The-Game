import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "../auth/auth-config-v2.js?v=20261001-5";

const root = document.querySelector("#session-app");
let supabase = null;
let currentUser = null;
let currentSessionId = null;
let currentPrefs = null;
let entry = null;
let factions = [];
let selectedFactionId = null;
let selectedFactionColor = null;
let seats = [];
let switchingFaction = false;
let factionManagement = [];
let factionActionStatus = [];
let rankings = [];
let rankingMode = "faction";
let gameState = null;
let statementContext = null;
let walletState = null;
let gamePollTimer = null;
let advanceTimer = null;
let debateOpen = false;
let debateMessages = [];
let debatePollTimer = null;
let countdownTimer = null;
let countdownTransitioning = false;
let loadError = null;

const UI = {
  "de-DE": { intro:"Einführung", read:"Ich habe die Einführung gelesen – weiter", choose:"Fraktion wählen", existing:"Bestehende Fraktionen", new:"Neue Fraktion", name:"Fraktionsname", namePlaceholder:"Name der Fraktion", position:"Position im Plenum", left:"Links", center:"Mitte", right:"Rechts", members:"Mitglieder", seats:"Sitze", chooseExisting:"Diese Fraktion wählen", create:"Fraktion gründen und Sitz wählen", assigned:"Dein Sitz ist zugewiesen", assignedText:"Du sitzt in einem zusammenhängenden Fraktionsblock.", seat:"Sitz", back:"Zurück zur Sitzungsübersicht", changeFaction:"Fraktion wechseln", cancel:"Abbrechen", loading:"Sitzung wird geladen …", error:"Die Sitzung konnte nicht geladen werden.", full:"Voll", selected:"Ausgewählt", required:"Bitte gib einen Fraktionsnamen ein und wähle eine Position.", factionFull:"Diese Fraktion hat bereits 10 Sitze.", sectorFull:"In diesem Sektor sind keine weiteren Fraktionsblöcke frei.", management:"Fraktionsverwaltung",hudPlayer:"Eigene Meinungspunkte",hudFaction:"Fraktions-Meinungspunkte",hudMoney:"Geld",president:"PRÄSIDENT",decision:"Deine Entscheidung",approve:"Zustimmung",interject:"Debatte",reject:"Ablehnung",voted:"Deine Entscheidung wurde gespeichert",factionVote:"Fraktionsstimme",resultApproved:"Fraktion stimmt zu",resultRejected:"Fraktion lehnt ab",resultTie:"Stimmengleichheit",nextStatement:"Nächste Aussage",voteError:"Entscheidung konnte nicht gespeichert werden.",debateTitle:"Debatte",debatePlaceholder:"Schreibe etwas zur aktuellen Sitzung …",debateSend:"Senden",debateClose:"Debatte schließen",debateEmpty:"Noch keine Beiträge. Starte die Debatte.",moderationRemoved:"Dein Beitrag verstößt gegen die Sitzungsregeln. Du wurdest aus dieser Sitzung entfernt.",waiting:"Warten auf die übrigen Fraktionsmitglieder …",points:"Punkte",eliminated:"AUSGESCHIEDEN",winnerPlayer:"SIEG · SPIELER",winnerFaction:"SIEG · FRAKTION",sessionEnded:"DIE SITZUNG IST BEENDET",leader:"Fraktionsvorsitz", deputy:"Stellvertretender Vorsitz", promote:"Zum Stellvertreter ernennen", removeDeputy:"Stellvertretung aufheben", kick:"Aus Fraktion entfernen", deleteFaction:"Fraktion löschen", deleteConfirm:"Fraktion wirklich löschen? Alle Mitglieder verlieren ihre Fraktionszugehörigkeit.", kickConfirm:"Mitglied wirklich aus der Fraktion entfernen?" , actions:"Fraktionsaktionen",actionHint:"Aktionen können zusätzliche leere Fraktionsplätze sichern. Besetzte Plätze werden niemals verdrängt.",speech:"Fraktionsrede · +1 Sitz · 1.500",committee:"Ausschussarbeit · +2 Sitze · 4.000",publicity:"Öffentlichkeitsarbeit · +3 Sitze · 9.000",actionError:"Aktion konnte nicht ausgeführt werden.",color:"Fraktionsfarbe",chooseColor:"Farbe wählen",saveColor:"Farbe speichern",colorSaved:"Fraktionsfarbe gespeichert.",colorTaken:"Diese Farbe wird bereits von einer anderen Fraktion verwendet.",colorPermission:"Nur Fraktionsvorsitz oder Stellvertretung kann die Fraktionsfarbe ändern.",invalidColor:"Ungültige Fraktionsfarbe.",seatCost1:"1 Sitz · 1.500",seatCost2:"2 Sitze · 4.000",seatCost3:"3 Sitze · 9.000",insufficientFunds:"Dafür reicht dein Geld nicht.",sessionMajority:"Sitzungsmehrheit",botTitle:"Fraktionsloser Bürger",botHint:"Dieser Bürger gehört keiner Fraktion an und kann beeinflusst werden.",botApprove:"Für Zustimmung beeinflussen",botReject:"Für Ablehnung beeinflussen",moral:"Moralisch überzeugen · kostenlos",bribe:"Bestechen · 750",botInfluenceError:"Der Bürger konnte nicht beeinflusst werden."},
  "es-ES": { intro:"Introducción", read:"He leído la introducción – continuar", choose:"Elegir grupo", existing:"Grupos existentes", new:"Nuevo grupo", name:"Nombre del grupo", namePlaceholder:"Nombre del grupo", position:"Posición en la cámara", left:"Izquierda", center:"Centro", right:"Derecha", members:"Miembros", seats:"Escaños", chooseExisting:"Elegir este grupo", create:"Crear grupo y elegir escaño", assigned:"Tu escaño está asignado", assignedText:"Te sientas en un bloque contiguo de tu grupo.", seat:"Escaño", back:"Volver al resumen", changeFaction:"Cambiar de grupo", cancel:"Cancelar", loading:"Cargando sesión …", error:"No se pudo cargar la sesión.", full:"Completo", selected:"Seleccionado", required:"Introduce un nombre y elige una posición.", factionFull:"Este grupo ya tiene 10 escaños.", sectorFull:"No quedan bloques libres en este sector." , actions:"Acciones del grupo",actionHint:"Las acciones pueden asegurar escaños vacíos adicionales. Los jugadores existentes nunca son desplazados.",speech:"Discurso del grupo · +1 escaño",committee:"Trabajo en comisión · +2 escaños",publicity:"Comunicación pública · +3 escaños",actionError:"No se pudo ejecutar la acción."},
  "fr-FR": { intro:"Introduction", read:"J’ai lu l’introduction – continuer", choose:"Choisir un groupe", existing:"Groupes existants", new:"Nouveau groupe", name:"Nom du groupe", namePlaceholder:"Nom du groupe", position:"Position dans l’hémicycle", left:"Gauche", center:"Centre", right:"Droite", members:"Membres", seats:"Sièges", chooseExisting:"Choisir ce groupe", create:"Créer le groupe et choisir un siège", assigned:"Votre siège est attribué", assignedText:"Vous êtes placé dans un bloc contigu de votre groupe.", seat:"Siège", back:"Retour au résumé", changeFaction:"Changer de groupe", cancel:"Annuler", loading:"Chargement de la session …", error:"Impossible de charger la session.", full:"Complet", selected:"Sélectionné", required:"Saisissez un nom et choisissez une position.", factionFull:"Ce groupe compte déjà 10 sièges.", sectorFull:"Aucun bloc libre dans ce secteur." , actions:"Actions du groupe",actionHint:"Les actions peuvent sécuriser des sièges vides supplémentaires. Aucun joueur en place n’est déplacé.",speech:"Discours du groupe · +1 siège",committee:"Travail en commission · +2 sièges",publicity:"Action publique · +3 sièges",actionError:"L’action n’a pas pu être exécutée."},
  "it-IT": { intro:"Introduzione", read:"Ho letto l’introduzione – continua", choose:"Scegli il gruppo", existing:"Gruppi esistenti", new:"Nuovo gruppo", name:"Nome del gruppo", namePlaceholder:"Nome del gruppo", position:"Posizione in aula", left:"Sinistra", center:"Centro", right:"Destra", members:"Membri", seats:"Seggi", chooseExisting:"Scegli questo gruppo", create:"Crea gruppo e scegli il seggio", assigned:"Il tuo seggio è assegnato", assignedText:"Sei inserito in un blocco contiguo del tuo gruppo.", seat:"Seggio", back:"Torna al riepilogo", changeFaction:"Cambia gruppo", cancel:"Annulla", loading:"Caricamento sessione …", error:"Impossibile caricare la sessione.", full:"Completo", selected:"Selezionato", required:"Inserisci un nome e scegli una posizione.", factionFull:"Questo gruppo ha già 10 seggi.", sectorFull:"Non ci sono altri blocchi liberi in questo settore." , actions:"Azioni del gruppo",actionHint:"Le azioni possono assicurare ulteriori seggi liberi. Nessun giocatore già seduto viene spostato.",speech:"Intervento del gruppo · +1 seggio",committee:"Lavoro in commissione · +2 seggi",publicity:"Azione pubblica · +3 seggi",actionError:"Impossibile eseguire l’azione."},
  "pt-BR": { intro:"Introdução", read:"Li a introdução – continuar", choose:"Escolher bancada", existing:"Bancadas existentes", new:"Nova bancada", name:"Nome da bancada", namePlaceholder:"Nome da bancada", position:"Posição no plenário", left:"Esquerda", center:"Centro", right:"Direita", members:"Membros", seats:"Assentos", chooseExisting:"Escolher esta bancada", create:"Criar bancada e escolher assento", assigned:"Seu assento foi atribuído", assignedText:"Você está em um bloco contíguo da sua bancada.", seat:"Assento", back:"Voltar ao resumo", changeFaction:"Trocar de bancada", cancel:"Cancelar", loading:"Carregando sessão …", error:"Não foi possível carregar a sessão.", full:"Lotada", selected:"Selecionada", required:"Digite um nome e escolha uma posição.", factionFull:"Esta bancada já tem 10 assentos.", sectorFull:"Não há mais blocos livres neste setor." , actions:"Ações da bancada",actionHint:"As ações podem garantir assentos vazios adicionais. Nenhum jogador já sentado é deslocado.",speech:"Discurso da bancada · +1 assento",committee:"Trabalho em comissão · +2 assentos",publicity:"Ação pública · +3 assentos",actionError:"Não foi possível executar a ação."},
  "en-US": { intro:"Introduction", read:"I have read the introduction – continue", choose:"Choose a faction", existing:"Existing factions", new:"New faction", name:"Faction name", namePlaceholder:"Faction name", position:"Position in the chamber", left:"Left", center:"Centre", right:"Right", members:"Members", seats:"Seats", chooseExisting:"Choose this faction", create:"Create faction and choose seat", assigned:"Your seat is assigned", assignedText:"You are placed in a contiguous faction block.", seat:"Seat", back:"Back to session overview", changeFaction:"Change faction", cancel:"Cancel", loading:"Loading session …", error:"The session could not be loaded.", full:"Full", selected:"Selected", required:"Enter a faction name and choose a position.", factionFull:"This faction already has 10 seats.", sectorFull:"No faction blocks are free in this sector.", management:"Faction management", leader:"Faction chair", deputy:"Deputy chair", promote:"Appoint deputy", removeDeputy:"Remove deputy", kick:"Remove from faction", deleteFaction:"Delete faction", deleteConfirm:"Delete this faction? All members will lose faction membership.", kickConfirm:"Remove this member from the faction?", actions:"Faction actions",actionHint:"Actions can secure additional empty faction seats. Players already seated are never displaced.",speech:"Faction speech · +1 seat",committee:"Committee work · +2 seats",publicity:"Public outreach · +3 seats",actionError:"The action could not be executed." }
};
function t(){ return Object.assign({},UI["de-DE"],UI[currentPrefs?.locale]||{}); }
function gt(){
  const x=t();
  return {
    playerPoints:x.playerPoints||x.hudPlayer||"Eigene Meinungspunkte",
    factionPoints:x.factionPoints||x.hudFaction||"Fraktions-Meinungspunkte",
    winnerPlayer:x.winnerPlayer||"SIEG · SPIELER",
    winnerFaction:x.winnerFaction||"SIEG · FRAKTION",
    winner:x.winner||"Gewinner",
    noWinner:x.noWinner||"Kein Gewinner",
    sessionEnded:x.sessionEnded||"DIE SITZUNG IST BEENDET",
    eliminated:x.eliminated||"AUSGESCHIEDEN",
    eliminatedText:x.eliminatedText||"Du bist ausgeschieden."
  };
}
function esc(v){return String(v??"").replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;").replaceAll("'","&#039;");}
function sideLabel(side){const x=t();return side==="left"?x.left:side==="center"?x.center:x.right;}

async function load(){
  root.hidden=false;
  loadError=null;
  root.innerHTML=`<div class="session-shell"><div class="session-loading">${t().loading}</div></div>`;

  try {
    const entryResult=await supabase.rpc("get_session_entry",{p_session_id:currentSessionId});
    if(entryResult.error) throw entryResult.error;
    if(!entryResult.data?.length) throw new Error("session_entry_not_found");
    entry=entryResult.data[0];

    factions=[]; seats=[]; factionManagement=[]; factionActionStatus=[]; gameState=null; statementContext=null;
    if(entry.read_confirmed){
      const results=await Promise.allSettled([
        supabase.rpc("get_session_factions",{p_session_id:currentSessionId}),
        supabase.rpc("get_session_seats",{p_session_id:currentSessionId}),
        supabase.rpc("get_session_game_state_v2",{p_session_id:currentSessionId}),
        supabase.rpc("get_session_statement_context",{p_session_id:currentSessionId}),
        supabase.rpc("get_session_wallet",{p_session_id:currentSessionId}),
        supabase.rpc("get_session_faction_management",{p_session_id:currentSessionId}),
        supabase.rpc("get_session_faction_actions",{p_session_id:currentSessionId}),
        supabase.rpc("get_session_rankings",{p_session_id:currentSessionId}),
      ]);
      const [fr,sr,gr,cr,mr,wr,ar,rr]=results;
      if(fr.status==="fulfilled" && !fr.value.error) factions=fr.value.data||[];
      if(sr.status==="fulfilled" && !sr.value.error) seats=sr.value.data||[];
      if(gr.status==="fulfilled" && !gr.value.error) gameState=gr.value.data?.[0]||null;
      if(cr.status==="fulfilled" && !cr.value.error) statementContext=cr.value.data?.[0]||null;
      if(wr.status==="fulfilled" && !wr.value.error) walletState=wr.value.data?.[0]||null;
      if(mr.status==="fulfilled" && !mr.value.error) factionManagement=mr.value.data||[];
      if(ar.status==="fulfilled" && !ar.value.error) factionActionStatus=ar.value.data||[];
      if(rr.status==="fulfilled" && !rr.value.error) rankings=rr.value.data||[];
      const failed=results.find(r=>r.status==="rejected" || r.value?.error);
      if(failed) loadError=failed.status==="rejected" ? (failed.reason?.message||String(failed.reason)) : (failed.value.error?.message||"Session-Daten konnten nicht vollständig geladen werden.");
    }
  } catch(error){
    loadError=error?.message||"Die Sitzung konnte nicht geladen werden.";
    entry=entry||null;
  }

  if(!entry){
    root.innerHTML=`<div class="session-shell"><div class="session-error">${esc(loadError||t().error)}</div><button class="session-secondary" type="button" data-back>${t().back}</button></div>`;
    const backButton=root.querySelector("[data-back]");
    if(backButton) backButton.addEventListener("click",back);
    return;
  }
  try {
    render();
    startStatementCountdown();
  } catch(error) {
    console.error("[Democrat] Session render error:", error);
    const message=error?.stack||error?.message||String(error);
    root.innerHTML=`<div class="session-shell"><div class="session-error"><strong>Sitzung konnte nicht dargestellt werden.</strong><br><small>${esc(message)}</small><br><button class="session-secondary" type="button" data-back>Zurück</button></div></div>`;
    const backButton=root.querySelector("[data-back]");
    if(backButton) backButton.addEventListener("click",back);
  }
}

async function refreshSessionSilently(){
  if(!supabase || !currentSessionId || !entry || !entry.read_confirmed) return;
  try {
    const [entryResult, gameResult, contextResult, walletResult, factionResult, seatResult, actionResult, rankResult] = await Promise.all([
      supabase.rpc("get_session_entry",{p_session_id:currentSessionId}),
      supabase.rpc("get_session_game_state_v2",{p_session_id:currentSessionId}),
      supabase.rpc("get_session_statement_context",{p_session_id:currentSessionId}),
      supabase.rpc("get_session_wallet",{p_session_id:currentSessionId}),
      supabase.rpc("get_session_factions",{p_session_id:currentSessionId}),
      supabase.rpc("get_session_seats",{p_session_id:currentSessionId}),
      supabase.rpc("get_session_faction_actions",{p_session_id:currentSessionId}),
      supabase.rpc("get_session_rankings",{p_session_id:currentSessionId}),
    ]);

    if(entryResult.error || gameResult.error) return;

    const nextEntry=entryResult.data?.[0];
    const nextGame=gameResult.data?.[0];
    if(!nextEntry || !nextGame) return;

    entry=nextEntry;
    gameState=nextGame;
    if(contextResult && !contextResult.error) statementContext=contextResult.data?.[0]||statementContext;
    if(walletResult && !walletResult.error) walletState=walletResult.data?.[0]||walletState;
    if(rankResult && !rankResult.error) rankings=rankResult.data||[];
    factions=factionResult.error ? factions : (factionResult.data||[]);
    seats=seatResult.error ? seats : (seatResult.data||[]);
    factionActionStatus=actionResult.error ? factionActionStatus : (actionResult.data||[]);
    const scrollY=window.scrollY;
    try {
      render();
      startStatementCountdown();
      window.scrollTo(0,scrollY);
    } catch(error) {
      console.error("[Democrat] Background session render error:", error);
    }
  } catch(_error) {
    // Background refresh failures must never blank or reload the active session.
  }
}
function renderChamber(){
  const playerId=currentUser?.id;
  const colorByName={
    red:"#d9534f",blue:"#3b82f6",green:"#22a06b",
    yellow:"#d8ad2d",purple:"#8b5cf6",orange:"#e47b28"
  };

  const totalPerSector=20;
  const rows=4;
  const columns=5;
  const innerRadius=21;
  const rowGap=5.0;
  const outerRadius=innerRadius+(rows-1)*rowGap;
  const sectorGap=4;
  const sectorSpan=(180-sectorGap*2)/3;
  const sectorDefs=[
    {key:"left",start:180,end:180-sectorSpan},
    {key:"center",start:90+sectorSpan/2,end:90-sectorSpan/2},
    {key:"right",start:sectorSpan,end:0}
  ];

  const point=(angleDeg,radius)=>{
    const a=angleDeg*Math.PI/180;
    return {
      x:50+Math.cos(a)*radius,
      y:88-Math.sin(a)*radius*0.72
    };
  };

  const sectorPath=(startDeg,endDeg)=>{
    const outerStart=point(startDeg,outerRadius+3);
    const outerEnd=point(endDeg,outerRadius+3);
    const innerEnd=point(endDeg,innerRadius-2);
    const innerStart=point(startDeg,innerRadius-2);
    return `M ${outerStart.x.toFixed(3)} ${outerStart.y.toFixed(3)}
      A ${(outerRadius+3).toFixed(3)} ${((outerRadius+3)*0.72).toFixed(3)} 0 0 0 ${outerEnd.x.toFixed(3)} ${outerEnd.y.toFixed(3)}
      L ${innerEnd.x.toFixed(3)} ${innerEnd.y.toFixed(3)}
      A ${(innerRadius-2).toFixed(3)} ${((innerRadius-2)*0.72).toFixed(3)} 0 0 1 ${innerStart.x.toFixed(3)} ${innerStart.y.toFixed(3)} Z`;
  };

  const bySide={left:[],center:[],right:[]};
  for(const seat of seats){
    const side=seat.side==="left"||seat.side==="center"||seat.side==="right"
      ? seat.side
      : (seat.seat_number<=20?"left":seat.seat_number<=40?"center":"right");
    bySide[side].push(seat);
  }
  Object.values(bySide).forEach(list=>list.sort((a,b)=>(a.seat_number||0)-(b.seat_number||0)));

  const sectorMarkup=[];
  const seatMarkup=[];

  for(const sector of sectorDefs){
    const list=bySide[sector.key].slice(0,totalPerSector);
    const fill=sector.key==="left"?"#334155":sector.key==="center"?"#3b4658":"#334155";
    sectorMarkup.push(
      `<path class="seat-sector" d="${sectorPath(sector.start,sector.end)}" fill="${fill}" opacity=".22">
        <title>${sideLabel(sector.key)} · 20 Sitze</title>
      </path>`
    );

    const span=sector.end-sector.start;
    for(let i=0;i<totalPerSector;i++){
      const seat=list[i]||{
        seat_number:sector.key==="left"?i+1:sector.key==="center"?i+21:i+41,
        side:sector.key,
        faction_id:null,
        faction_name:null,
        faction_color:null,
        user_id:null,
        profile_name:null
      };

      const row=Math.floor(i/columns);
      const col=i%columns;
      const angle=sector.start+((col+0.5)/columns)*span;
      const radius=innerRadius+row*rowGap;
      const p=point(angle,radius);
      const occupied=Boolean(seat.user_id);
      const bot=Boolean(seat.bot_id||seat.is_bot);
      const controlled=Boolean(seat.faction_id)&&!occupied&&!bot;
      const own=seat.user_id===playerId;
      const factionBot=bot&&Boolean(seat.faction_id);
      const colorClass=seat.faction_color ? " faction-"+esc(seat.faction_color) : "";
      const cls=own
        ? "seat own-seat"+colorClass
        : factionBot
          ? "seat bot-seat faction-bot-seat"+colorClass
        : bot
          ? "seat bot-seat"
          : occupied
            ? "seat occupied-seat"+colorClass
            : controlled
              ? "seat controlled-empty-seat"+colorClass
              : "seat";
      const title=factionBot
        ? esc(t().factionBot)+" · "+esc(seat.faction_name||"")
        : bot
          ? esc(seat.profile_name||"Bürger")
          : occupied
          ? esc(seat.profile_name)+" · "+esc(seat.faction_name||"")
          : controlled
            ? "Fraktionsplatz · "+esc(seat.faction_name||"")
            : "Freier Sitz · "+esc(sideLabel(sector.key));

      seatMarkup.push(bot&&!factionBot
        ? `<button class="${cls}" style="--x:${p.x.toFixed(3)}%;--y:${p.y.toFixed(3)}%" title="${title}" data-bot-id="${esc(seat.bot_id)}" aria-label="${title}"><span class="seat-dot"></span></button>`
        : `<div class="${cls}" style="--x:${p.x.toFixed(3)}%;--y:${p.y.toFixed(3)}%" title="${title}"><span class="seat-dot"></span></div>`
      );
    }
  }

  return `<div class="chamber-wrap">
    <div class="chamber-title">Sitzverteilung · 60 Sitze</div>
    <div class="hemicycle-map">
      <div class="presidium"><span>PRÄSIDIUM</span><small>Präsident / Präsidium</small></div>
      <svg class="seat-sector-map" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
        <path class="seat-arc" d="M 8 88 A 45 32.4 0 0 1 92 88"></path>
        <path class="seat-inner-arc" d="M 29 88 A 23 16.56 0 0 1 71 88"></path>
        ${sectorMarkup.join("")}
      </svg>
      <div class="hemicycle-floor"></div>
      <div class="chamber-seats">${seatMarkup.join("")}</div>
    </div>
    <div class="chamber-legend">
      ${factions.map(f=>`<span><i class="legend-dot faction-${esc(f.color_code||"blue")}"></i>${esc(f.name)} · ${f.member_count}/10</span>`).join("")}
    </div>
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
  if(selectedFactionId){
    html+="<button class=\"session-primary faction-confirm\" type=\"button\" data-existing>"+x.chooseExisting+"</button>";
  }
  html+="<div class=\"new-faction\"><h3>"+x.new+"</h3><label>"+x.name+"<input id=\"faction-name\" maxlength=\"40\" placeholder=\""+x.namePlaceholder+"\"></label><fieldset><legend>"+x.position+"</legend><div class=\"side-options\">";
  html+=renderSideOptions(x);
  html+="</div></fieldset><div class=\"faction-color-picker\"><h3>"+x.color+" <span>"+x.chooseColor+"</span></h3><div class=\"color-options\">";["red","blue","green","yellow","purple","orange"].forEach(color=>{const used=factions.some(f=>f.color_code===color);html+="<button type=\"button\" class=\"color-choice faction-"+color+(used?" unavailable":"")+(selectedFactionColor===color?" selected":"")+"\" data-new-faction-color=\""+color+"\" "+(used?"disabled":"")+" aria-label=\""+color+"\"></button>";});html+="</div></div><button class=\"session-primary\" type=\"button\" data-create>"+x.create+"</button><div id=\"session-action-error\" class=\"session-action-error\" hidden></div></div></div>";
  return html;
}
function pct(value){return Math.max(0,Math.min(100,Number(value||0)));}
function renderRankings(){
  const factionRows=rankings.filter(r=>r.ranking_type==="faction");
  const playerRows=rankings.filter(r=>r.ranking_type==="player");
  const rows=rankingMode==="faction"?factionRows:playerRows;
  const title=rankingMode==="faction"?"Fraktionsrangliste":"Spieler-Rangliste";
  const tabs='<div class="ranking-tabs"><button type="button" class="ranking-tab '+(rankingMode==="faction"?"active":"")+'" data-ranking-mode="faction">Fraktionsrangliste</button><button type="button" class="ranking-tab '+(rankingMode==="player"?"active":"")+'" data-ranking-mode="player">Spieler-Rangliste</button></div>';
  const list=rows.length?'<div class="ranking-list">'+rows.map((r,i)=>'<div class="ranking-row '+(r.eliminated?"ranking-eliminated":"")+'"><span class="ranking-rank">'+(i+1)+'.</span><span class="ranking-name"><strong>'+esc(r.subject_name)+'</strong>'+(rankingMode==="player"&&r.faction_name?'<small>'+esc(r.faction_name)+'</small>':"")+'</span><strong class="ranking-points">'+Number(r.points||0)+'/100</strong></div>').join("")+'</div>':'<div class="session-empty">Noch keine Einträge.</div>';
  return '<section class="ranking-panel"><div class="ranking-heading"><div><div class="session-label">Rangliste</div><h3>'+title+'</h3></div></div>'+tabs+list+'</section>';
}
function renderGameHud(){const x=gt(),g=gameState||{},w=walletState||{};const money=Number(w.money??g.money??0);const symbol=w.currency_symbol||"€";return '<div class="game-hud"><div class="hud-card"><span>'+x.playerPoints+'</span><strong>'+pct(g.player_opinion_points)+'/100</strong><small>'+(g.player_eliminated?x.eliminated:'')+'</small></div><div class="hud-card"><span>'+x.factionPoints+'</span><strong>'+pct(g.faction_opinion_points)+'/100</strong><small>'+(g.faction_eliminated?x.eliminated:'')+'</small></div><div class="hud-card"><span>'+t().hudMoney+'</span><strong>'+money.toLocaleString(undefined)+' '+symbol+'</strong><small>'+Number(w.salary_per_minute||0).toLocaleString(undefined)+' '+symbol+' / Min.</small></div></div>';}
function getStatementDeadline(){
  if(gameState?.statement_deadline)return gameState.statement_deadline;
  if(gameState?.statement_opened_at)return new Date(new Date(gameState.statement_opened_at).getTime()+10*60*1000).toISOString();
  return null;
}
function formatStatementCountdown(deadline){
  const serverNow=gameState?.server_now?new Date(gameState.server_now).getTime():Date.now();
  const clockOffset=serverNow-Date.now();
  const ms=Math.max(0,new Date(deadline||0).getTime()-(Date.now()+clockOffset));
  const total=Math.ceil(ms/1000);
  const minutes=Math.floor(total/60);
  const seconds=total%60;
  return String(minutes).padStart(2,"0")+":"+String(seconds).padStart(2,"0");
}
function renderPresidentStatement(){
  const x=t(),g=gameState||{},c=statementContext||{},resolved=g.statement_status==="resolved",ended=g.session_status==="ended";
  let body="";
  if(ended){
    const kind=g.winner_type==="faction"?gt().winnerFaction:g.winner_type==="player"?gt().winnerPlayer:"";
    body='<div class="session-ended-banner">'+gt().sessionEnded+'</div>'+(g.winner_name?'<div class="winner-card"><strong>'+gt().winner+' · '+esc(kind)+'</strong><span>'+esc(g.winner_name)+'</span></div>':'<div class="winner-card"><span>'+gt().noWinner+'</span></div>');
  }else{
    const typeLabels={gesetzesvorlage:"Gesetzesvorlage",haushaltsentscheidung:"Haushaltsentscheidung",verwaltungsentscheidung:"Verwaltungsentscheidung",parlamentarische_entscheidung:"Parlamentarische Entscheidung",parliamentary_decision:"Parlamentarische Entscheidung"};
    const decisionType=typeLabels[c.decision_type]||"Parlamentarische Entscheidung";
    const decisionStage=c.decision_stage||"Einzelentscheidung";
    body='<div class="president-label">'+x.president+' · Tagesordnungspunkt '+(g.statement_number||"")+'</div>'+
      '<div class="statement-meta"><span>'+esc(decisionType)+'</span><span>'+esc(c.political_area||"Politik")+'</span><span>'+esc(decisionStage)+'</span></div>'+
      (g.statement_text?'<h2>'+esc(g.statement_text)+'</h2>':"")+
      (c.context_text?'<p class="statement-context">'+esc(c.context_text)+'</p>':"")+
      (g.statement_status==="open"&&g.session_status==="active"&&getStatementDeadline()?'<div class="statement-countdown"><span id="statement-countdown-label">'+(countdownTransitioning?"Entscheidung wird ausgewertet …":"Nächste Entscheidung in")+'</span><strong id="statement-countdown">'+formatStatementCountdown(getStatementDeadline())+'</strong></div>':"")+
      (resolved?'<div class="statement-resolved">'+(g.outcome==="approved"?x.resultApproved:g.outcome==="rejected"?x.resultRejected:x.resultTie)+'</div>'+(c.consequence_text?'<p class="statement-consequence">'+esc(c.consequence_text)+'</p>':""):"");
  }
  return '<section class="president-statement">'+body+'</section>';
}
async function influenceBot(botId,choice,method){try{const {error}=await supabase.rpc("influence_session_bot",{p_session_id:currentSessionId,p_bot_id:botId,p_choice:choice,p_method:method});if(error)throw error;await load();}catch(error){alert(error?.message?.includes("insufficient_funds")?t().insufficientFunds:t().botInfluenceError);}}
function openBotDialog(botId){const bot=seats.find(s=>String(s.bot_id||"")===String(botId));if(!bot||!gameState||gameState.statement_status!=="open"||gameState.session_status!=="active")return;const x=t(),overlay=document.createElement("div");overlay.className="bot-dialog-backdrop";overlay.innerHTML='<section class="bot-dialog" role="dialog" aria-modal="true"><div class="bot-dialog-head"><div><div class="session-label">'+x.botTitle+'</div><h2>'+esc(bot.profile_name||"Bürger")+'</h2></div><button type="button" class="debate-close" data-bot-close>×</button></div><p>'+x.botHint+'</p><div class="bot-choice-grid"><button type="button" class="session-secondary" data-bot-choice="approve">'+x.botApprove+'</button><button type="button" class="session-secondary" data-bot-choice="reject">'+x.botReject+'</button></div><div class="bot-method-grid"><button type="button" class="session-primary bot-method" data-bot-method="moral">'+x.moral+'</button><button type="button" class="session-primary bot-method" data-bot-method="bribe">'+x.bribe+'</button></div></section>';document.body.appendChild(overlay);let selectedChoice="approve";overlay.querySelector('[data-bot-choice="approve"]')?.classList.add("selected");overlay.querySelectorAll("[data-bot-choice]").forEach(b=>b.addEventListener("click",()=>{selectedChoice=b.dataset.botChoice;overlay.querySelectorAll("[data-bot-choice]").forEach(x=>x.classList.remove("selected"));b.classList.add("selected");}));overlay.querySelectorAll("[data-bot-method]").forEach(b=>b.addEventListener("click",async()=>{b.disabled=true;await influenceBot(botId,selectedChoice,b.dataset.botMethod);overlay.remove();}));overlay.querySelector("[data-bot-close]")?.addEventListener("click",()=>overlay.remove());}
function renderFactionVote(){const x=t(),g=gameState||{},yes=Number(g.faction_approve_votes||0),no=Number(g.faction_reject_votes||0),inter=Number(g.faction_interject_votes||0),d=yes+no,yp=d?Math.round(yes/d*100):0,np=d?100-yp:0;const result=g.statement_status==="resolved"?(g.outcome==="approved"?x.resultApproved:g.outcome==="rejected"?x.resultRejected:x.resultTie):"";return '<div class="faction-vote-panel"><div class="faction-vote-head"><span>'+x.factionVote+'</span><strong>'+d+'/'+(g.faction_member_count||0)+'</strong></div><div class="faction-vote-bar"><i style="width:'+yp+'%"></i><b style="width:'+np+'%"></b></div><div class="faction-vote-numbers"><span>'+x.approve+': '+yp+'%</span><span>'+x.reject+': '+np+'%</span>'+(inter?'<span>'+x.interject+': '+inter+'</span>':'')+'</div>'+(result?'<div class="faction-result">'+result+'</div>':(d<Number(g.faction_member_count||0)?'<div class="faction-waiting">'+x.waiting+'</div>':''))+'</div>';}
function renderSessionMajority(){
  const x=t(),g=gameState||{};
  const yes=Number(g.approve_votes||0),no=Number(g.reject_votes||0),d=yes+no;
  const yp=d?Math.round(yes/d*100):0,np=d?100-yp:0;
  const result=g.statement_status==="resolved"
    ?(g.outcome==="approved"?x.resultApproved:g.outcome==="rejected"?x.resultRejected:x.resultTie)
    :"";
  return '<div class="faction-vote-panel session-majority-panel"><div class="faction-vote-head"><span>'+x.sessionMajority+'</span><strong>'+d+' Stimmen</strong></div><div class="faction-vote-bar"><i style="width:'+yp+'%"></i><b style="width:'+np+'%"></b></div><div class="faction-vote-numbers"><span>'+x.approve+': '+yp+'%</span><span>'+x.reject+': '+np+'%</span></div>'+(result?'<div class="faction-result">'+result+'</div>':'')+'</div>';
}
async function castVote(choice){
  if(choice==="debate"){openDebate();return;}
  if(!gameState||gameState.statement_status!=="open"||gameState.session_status!=="active"||gameState.my_choice||gameState.player_eliminated||gameState.faction_eliminated)return;
  const bs=[...root.querySelectorAll(".decision-button")];bs.forEach(b=>b.disabled=true);
  const {error}=await supabase.rpc("cast_session_vote",{p_session_id:currentSessionId,p_choice:choice});
  if(error){bs.forEach(b=>b.disabled=false);const box=root.querySelector("#vote-error");if(box){box.hidden=false;box.textContent=error.message?.includes("player_eliminated")?gt().eliminatedText:error.message?.includes("faction_eliminated")?gt().factionPoints+" · "+gt().eliminated:t().voteError;}return;}
  await load();
}
function openDebate(){
  if(!currentSessionId||debateOpen)return;
  debateOpen=true;
  const x=t();
  const overlay=document.createElement("div");
  overlay.className="debate-overlay";
  overlay.id="debate-overlay";
  overlay.innerHTML=`<section class="debate-window" role="dialog" aria-modal="true" aria-label="${x.debateTitle}">
    <header class="debate-header">
      <div><div class="session-label">${x.debateTitle}</div><h2>${esc(entry?.topic_title||entry?.display_name||"")}</h2></div>
      <button type="button" class="debate-close" data-debate-close aria-label="${x.debateClose}">×</button>
    </header>
    <div class="debate-messages" id="debate-messages"><div class="session-empty">${x.debateEmpty}</div></div>
    <form class="debate-composer" id="debate-form">
      <textarea id="debate-input" maxlength="500" rows="3" placeholder="${x.debatePlaceholder}" required></textarea>
      <button type="submit" class="session-primary">${x.debateSend}</button>
    </form>
    <div id="debate-error" class="session-action-error" hidden></div>
  </section>`;
  document.body.appendChild(overlay);
  overlay.querySelector("[data-debate-close]")?.addEventListener("click",closeDebate);
  overlay.querySelector("#debate-form")?.addEventListener("submit",sendDebateMessage);
  overlay.addEventListener("keydown",event=>{if(event.key==="Escape")closeDebate();});
  refreshDebateMessages();
  if(debatePollTimer)window.clearInterval(debatePollTimer);
  debatePollTimer=window.setInterval(()=>{if(debateOpen&&document.visibilityState!=="hidden")refreshDebateMessages();},3000);
  window.setTimeout(()=>overlay.querySelector("#debate-input")?.focus(),50);
}
async function refreshDebateMessages(){
  if(!debateOpen||!currentSessionId)return;
  try{
    const {data,error}=await supabase.rpc("get_session_debate_messages",{p_session_id:currentSessionId,p_limit:200});
    if(error||!data)return;
    debateMessages=data.slice().reverse();
    renderDebateMessages();
  }catch(_error){}
}
function renderDebateMessages(){
  const box=document.querySelector("#debate-messages");
  if(!box)return;
  const wasNearBottom=box.scrollHeight-box.scrollTop-box.clientHeight<100;
  box.innerHTML=debateMessages.length?debateMessages.map(m=>`<article class="debate-message"><div class="debate-message-meta"><strong>${esc(m.profile_name||"Spieler")}</strong><time>${new Date(m.created_at).toLocaleTimeString([], {hour:"2-digit",minute:"2-digit"})}</time></div><div class="debate-message-text">${esc(m.message)}</div></article>`).join(""):`<div class="session-empty">${esc(t().debateEmpty)}</div>`;
  if(wasNearBottom)box.scrollTop=box.scrollHeight;
}
async function sendDebateMessage(event){
  event.preventDefault();
  const input=document.querySelector("#debate-input");
  const button=document.querySelector("#debate-form button");
  const errorBox=document.querySelector("#debate-error");
  const message=input?.value?.trim()||"";
  if(!message)return;
  if(button)button.disabled=true;
  if(errorBox){errorBox.hidden=true;errorBox.textContent="";}
  try{
    const {data,error}=await supabase.rpc("send_session_debate_message",{p_session_id:currentSessionId,p_message:message});
    if(error)throw error;
    if(data?.[0]?.status==="removed"){
      closeDebate();
      root.innerHTML=`<div class="session-shell"><div class="session-error">${esc(t().moderationRemoved)}</div><button class="session-secondary" type="button" data-back>${t().back}</button></div>`;
      root.querySelector("[data-back]")?.addEventListener("click",back);
      return;
    }
    if(input)input.value="";
    await refreshDebateMessages();
  }catch(error){
    if(errorBox){errorBox.hidden=false;errorBox.textContent=error?.message||t().debatePlaceholder;}
  }finally{
    if(button)button.disabled=false;
  }
}
function closeDebate(){
  debateOpen=false;
  if(debatePollTimer)window.clearInterval(debatePollTimer);
  debatePollTimer=null;
  document.querySelector("#debate-overlay")?.remove();
}

async function advanceStatement(){if(!gameState||gameState.statement_status!=="resolved"||gameState.session_status!=="active")return;await supabase.rpc("advance_session_statement",{p_session_id:currentSessionId});await load();}
function formatCooldown(seconds){
  const total=Math.max(0,Number(seconds||0));
  const minutes=Math.floor(total/60);
  const secs=Math.floor(total%60);
  return String(minutes).padStart(2,"0")+":"+String(secs).padStart(2,"0");
}
function renderFactionActions(){
  const x=t();
  const labels={fraktionsrede:x.speech,ausschussarbeit:x.committee,oeffentlichkeitsarbeit:x.publicity};
  const rows=factionActionStatus||[];
  const maxExtra=10;
  const claimed=Math.max(0,...rows.map(r=>Number(r.extra_seats_claimed||0)));
  return `<div class="faction-actions">
    <h3>${x.actions}</h3>
    <p>${x.actionHint}</p>
    <div class="faction-seat-capacity"><strong>${x.extraSeats}: ${claimed}/${maxExtra}</strong></div>
    <div class="faction-action-grid">
      ${rows.map(r=>{
        const remaining=Number(r.cooldown_remaining_seconds||0);
        const reward=Number(r.seat_reward||0);
        const maxed=Number(r.extra_seats_claimed||0)>=maxExtra;
        const noBots=Number(r.available_bot_seats||0)<reward;
        const cost=reward===1?1500:reward===2?4000:reward===3?9000:0;
        const noMoney=Number(walletState?.money||0)<cost;
        const disabled=remaining>0||maxed||noBots||noMoney;
        const status=maxed
          ? `${x.extraSeats}: ${maxExtra}/${maxExtra}`
          : remaining>0
            ? `${x.cooldown}: ${formatCooldown(remaining)}`
            : noBots
              ? x.noBotSeats
              : noMoney
                ? x.insufficientFunds
                : x.cooldownReady;
        return `<button type="button" class="session-secondary faction-action" data-action="${esc(r.action_code)}" ${disabled?"disabled":""}>
          <span>${labels[r.action_code]||esc(r.action_code)}</span><small>${status}</small>
        </button>`;
      }).join("")}
    </div>
    <div id="faction-action-error" class="session-action-error" hidden></div>
  </div>`;
}
async function performFactionAction(code){
  const box=root.querySelector("#faction-action-error");
  const {error}=await supabase.rpc("perform_faction_action",{p_session_id:currentSessionId,p_action_code:code});
  if(error){
    if(box){
      box.hidden=false;
      const msg=error.message||"";
      box.textContent=msg.includes("action_cooldown") ? t().cooldown :
        msg.includes("faction_extra_seat_limit") ? t().extraSeats+" · "+t().maxExtraSeats :
        msg.includes("not_enough_neutral_bot_seats") ? t().noBotSeats :
        t().actionError;
    }
    await load();
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
  const faction=factions.find(f=>f.id===entry.faction_id);
  const colors=["red","blue","green","yellow","purple","orange"];
  const used=new Set(factions.filter(f=>f.id!==entry.faction_id).map(f=>f.color_code));
  html+="<div class=\"faction-color-management\"><strong>"+x.color+"</strong><div class=\"color-options\">";
  colors.forEach(color=>{
    const selected=faction?.color_code===color;
    const unavailable=used.has(color);
    html+="<button type=\"button\" class=\"color-choice faction-"+color+(selected?" selected":"")+(unavailable?" unavailable":"")+"\" data-management-color=\""+color+"\" "+(unavailable?"disabled":"")+" aria-label=\""+color+"\"></button>";
  });
  html+="</div><small>"+x.chooseColor+"</small></div>";
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
async function handleStatementCountdown(){
  if(!gameState||gameState.statement_status!=="open"||gameState.session_status!=="active")return;
  const deadline=getStatementDeadline();
  if(!deadline)return;
  const el=root.querySelector("#statement-countdown");
  const label=root.querySelector("#statement-countdown-label");
  const serverNow=gameState.server_now?new Date(gameState.server_now).getTime():Date.now();
  const clockOffset=serverNow-Date.now();
  const remaining=Math.max(0,new Date(deadline).getTime()-(Date.now()+clockOffset));
  if(remaining<=0){
    if(el)el.textContent="00:00";
    if(label)label.textContent="Entscheidung wird ausgewertet …";
    countdownTransitioning=true;
    if(advanceTimer===null){
      advanceTimer=window.setTimeout(async()=>{
        advanceTimer=null;
        try{await supabase.rpc("advance_session_statement",{p_session_id:currentSessionId});}
        finally{countdownTransitioning=false;await load();}
      },250);
    }
    return;
  }
  countdownTransitioning=false;
  if(el)el.textContent=formatStatementCountdown(deadline);
  if(label)label.textContent="Nächste Entscheidung in";
}
function startStatementCountdown(){
  if(countdownTimer)window.clearInterval(countdownTimer);
  countdownTimer=window.setInterval(handleStatementCountdown,1000);
  handleStatementCountdown();
}
function render(){
  const x=t();
  const assigned=entry.faction_id&&entry.seat_number;
  root.innerHTML=`
  <div class="session-shell">
    <header class="session-header">
      <div><img class="game-logo session-logo" src="./assets/democrat-logo.svg" alt="Democrat – The Game"><h1>${esc(entry.display_name)}</h1><div class="session-chamber">${esc(entry.chamber_name)} · ${entry.player_count}/${entry.max_players} Spieler · 60/60 Sitze</div></div>
      <button class="session-back" type="button" data-back>×</button>
    </header>
    <main class="session-main">\n       ${loadError ? `<div class="session-action-error">${esc(loadError)}</div>` : ""}
      ${!entry.read_confirmed ? `
        <section class="session-panel session-intro">
          <div class="session-label">${x.intro}</div>
          <h2>${esc(entry.topic_title||entry.display_name)}</h2>
          <p>${esc(entry.topic_intro||"")}</p>
          <button class="session-primary" type="button" data-read>${x.read}</button>
        </section>`
      : assigned ? `
        <section class="session-panel session-assigned">
          ${renderGameHud()}
          ${renderPresidentStatement()}
          ${renderFactionVote()}
           ${renderSessionMajority()}
           ${gameState?.my_choice ? `<div class="vote-recorded">${x.voted} · ${gameState.my_choice==="approve"?x.approve:gameState.my_choice==="reject"?x.reject:x.interject}</div>` : ""}
          <div id="vote-error" class="session-action-error" hidden></div>
          <div class="session-label">${x.assigned}</div>
          <h2>${esc(entry.faction_name)}</h2>
          <p>${sideLabel(entry.faction_side)} · ${x.seat} <strong>${entry.seat_number}</strong></p>
          <div class="session-seat-note">${x.assignedText}</div>
          ${renderChamber()}
          ${(!gameState?.player_eliminated && gameState?.session_status!=="ended") ? renderFactionActions() : ""}${renderFactionManagement()}${(!gameState?.player_eliminated && gameState?.session_status!=="ended") ? (switchingFaction ? renderFactionChooser(x) : `<button class="session-primary" type="button" data-switch>${x.changeFaction}</button>`) : ""}
          ${switchingFaction ? `<button class="session-secondary" type="button" data-cancel-switch>${x.cancel}</button>` : ""}
        
          </section>`
      : `
        <section class="session-panel">
          <div class="session-label">${x.choose}</div>
          <h2>${esc(entry.topic_title||entry.display_name)}</h2>
          <div class="faction-grid">
            ${factions.length ? factions.map(f=>`<button class="faction-card ${selectedFactionId===f.id?"selected":""} ${f.eliminated?"faction-eliminated":""}" data-faction="${f.id}" type="button" ${f.eliminated?"disabled":""}><strong>${esc(f.name)}</strong><span>${sideLabel(f.side)}</span><small>${f.approval}/100 ${x.points} · ${f.member_count}/10 ${x.members}${f.eliminated?" · "+x.eliminated:""}</small></button>`).join("") : `<div class="session-empty">${x.existing}: —</div>`}
          </div>
          ${selectedFactionId ? `<button class="session-primary faction-confirm" type="button" data-existing>${x.chooseExisting}</button>` : ""}
          <div class="new-faction">
            <h3>${x.new}</h3>
            <label>${x.name}<input id="faction-name" maxlength="40" placeholder="${x.namePlaceholder}"></label>
            <fieldset><legend>${x.position}</legend><div class="side-options">${renderSideOptions(x)}</div></fieldset>
            <div class="faction-color-picker"><h3>${x.color} <span>${x.chooseColor}</span></h3><div class="color-options">${["red","blue","green","yellow","purple","orange"].map(color=>{const used=factions.some(f=>f.color_code===color);return "<button type=\"button\" class=\"color-choice faction-"+color+(used?" unavailable":"")+(selectedFactionColor===color?" selected":"")+" \" data-new-faction-color=\""+color+"\" "+(used?"disabled":"")+" aria-label=\""+color+"\"></button>";}).join("")}</div></div>
            <button class="session-primary" type="button" data-create>${x.create}</button>
            <div id="session-action-error" class="session-action-error" hidden></div>
          </div>
        </section>`}
    ${gameState?.statement_status==="open" && !gameState?.player_eliminated && gameState?.session_status!=="ended" ? `<div class="decision-bar"><div class="decision-title">${x.decision}</div><div class="decision-buttons"><button class="decision-button approve" type="button" data-vote="approve" ${gameState?.my_choice?"disabled":""}>${x.approve}</button><button class="decision-button interject" type="button" data-vote="debate" ${gameState?.my_choice?"disabled":""}>${x.interject}</button><button class="decision-button reject" type="button" data-vote="reject" ${gameState?.my_choice?"disabled":""}>${x.reject}</button></div></div>` : ""}
    </main>
  </div>`;
  root.querySelectorAll("[data-back]").forEach(b=>b.addEventListener("click",()=>back()));
  const sw=root.querySelector("[data-switch]"); if(sw) sw.addEventListener("click",()=>{switchingFaction=true;render();});
  const cs=root.querySelector("[data-cancel-switch]"); if(cs) cs.addEventListener("click",()=>{switchingFaction=false;selectedFactionId=null;render();});
  const read=root.querySelector("[data-read]"); if(read) read.addEventListener("click",confirmRead);
  root.querySelectorAll("[data-vote]").forEach(b=>b.addEventListener("click",()=>castVote(b.dataset.vote)));
  root.querySelectorAll("[data-ranking-mode]").forEach(b=>b.addEventListener("click",()=>{rankingMode=b.dataset.rankingMode==="player"?"player":"faction";render();startStatementCountdown();}));
  root.querySelectorAll("[data-bot-id]").forEach(b=>b.addEventListener("click",()=>openBotDialog(b.dataset.botId)));
  root.querySelectorAll("[data-faction]").forEach(b=>b.addEventListener("click",()=>{selectedFactionId=b.dataset.faction;selectedFactionColor=null;render();}));
  root.querySelectorAll("[data-faction-color]").forEach(b=>b.addEventListener("click",()=>{selectedFactionColor=b.dataset.factionColor;render();}));
  root.querySelectorAll("[data-new-faction-color]").forEach(b=>b.addEventListener("click",()=>{selectedFactionColor=b.dataset.newFactionColor;render();}));
  root.querySelectorAll("[data-management-color]").forEach(b=>b.addEventListener("click",async()=>{
    const color=b.dataset.managementColor;
    b.disabled=true;
    const {error}=await supabase.rpc("set_session_faction_color",{p_session_id:currentSessionId,p_color_code:color});
    if(error) alert(mapFactionError(error));
    await load();
  }));
  const create=root.querySelector("[data-create]"); if(create) create.addEventListener("click",chooseNew);
  const existing=root.querySelector("[data-existing]"); if(existing) existing.addEventListener("click",chooseExisting);
  root.querySelectorAll("[data-action]").forEach(b=>b.addEventListener("click",()=>performFactionAction(b.dataset.action)));
  root.querySelectorAll("[data-kick]").forEach(b=>b.addEventListener("click",()=>factionAction("kick",b.dataset.kick)));
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
  if(code==="player_eliminated"||msg.includes("player_eliminated"))return t().eliminated;
  if(code==="faction_eliminated"||msg.includes("faction_eliminated"))return t().eliminated;
  if(msg.includes("action_cooldown"))return t().cooldown;
  if(msg.includes("faction_extra_seat_limit"))return t().extraSeats+" · "+t().maxExtraSeats;
  if(msg.includes("not_enough_neutral_bot_seats"))return t().noBotSeats;
  if(msg.includes("insufficient_funds"))return t().insufficientFunds;
  if(msg.includes("faction_color_taken"))return t().colorTaken;
  if(msg.includes("faction_color_permission_denied"))return t().colorPermission;
  if(msg.includes("invalid_faction_color"))return t().invalidColor;
  if(code==="session_ended"||msg.includes("session_ended"))return t().sessionEnded;
  return msg||t().required;
}
async function chooseExisting(){
  if(!selectedFactionId)return;
  const err=root.querySelector("#session-action-error");
  const {error}=await supabase.rpc("choose_session_faction",{p_session_id:currentSessionId,p_faction_id:selectedFactionId,p_faction_name:null,p_side:null,p_color_code:null});
  if(error){err.textContent=mapFactionError(error);err.hidden=false;return;}
  if(selectedFactionColor){
    const colorResult=await supabase.rpc("set_session_faction_color",{p_session_id:currentSessionId,p_color_code:selectedFactionColor});
    if(colorResult.error){err.textContent=mapFactionError(colorResult.error);err.hidden=false;return;}
  }
  selectedFactionId=null;selectedFactionColor=null;switchingFaction=false;await load();
}

async function chooseNew(){
  const x=t(),name=root.querySelector("#faction-name")?.value.trim(),side=root.querySelector("input[name='side']:checked")?.value;
  const err=root.querySelector("#session-action-error");
  if(!name||!side){err.textContent=x.required;err.hidden=false;return;}
  const {data,error}=await supabase.rpc("choose_session_faction",{p_session_id:currentSessionId,p_faction_id:selectedFactionId,p_faction_name:selectedFactionId?null:name,p_side:selectedFactionId?null:side,p_color_code:selectedFactionId?null:(selectedFactionColor||null)});
  if(error){err.textContent=mapFactionError(error);err.hidden=false;return;}
  if(selectedFactionColor){
    const colorResult=await supabase.rpc("set_session_faction_color",{p_session_id:currentSessionId,p_color_code:selectedFactionColor});
    if(colorResult.error){err.textContent=mapFactionError(colorResult.error);err.hidden=false;return;}
  }
  selectedFactionId=null;selectedFactionColor=null;switchingFaction=false;await load();
}

function back(){
  closeDebate();
  root.hidden=true;root.innerHTML="";
  window.dispatchEvent(new CustomEvent("democrat:session-back"));
}
export async function mount(user,sessionId,prefs){
  if(!root)return;
  if(gamePollTimer)window.clearInterval(gamePollTimer);
  if(advanceTimer)window.clearTimeout(advanceTimer);
   closeDebate();
  root.hidden=false;
  if(!SUPABASE_PUBLISHABLE_KEY||SUPABASE_PUBLISHABLE_KEY.startsWith("REPLACE_"))return;
  supabase=createClient(SUPABASE_URL,SUPABASE_PUBLISHABLE_KEY);currentUser=user;currentSessionId=sessionId;currentPrefs=prefs||{};selectedFactionId=null;switchingFaction=false;gameState=null;loadError=null;
  try {
    await load();
  } catch(error) {
    console.error("[Democrat] Session mount error:", error);
    root.hidden=false;
    root.innerHTML=`<div class="session-shell"><div class="session-error"><strong>Sitzung konnte nicht geladen werden.</strong><br><small>${esc(error?.stack||error?.message||String(error))}</small><br><button class="session-secondary" type="button" data-back>Zurück</button></div></div>`;
    const backButton=root.querySelector("[data-back]");
    if(backButton) backButton.addEventListener("click",back);
    return;
  }
  gamePollTimer=window.setInterval(()=>{if(document.visibilityState!=="hidden")refreshSessionSilently();},3000);
}
export function unmount(){if(gamePollTimer)window.clearInterval(gamePollTimer);if(advanceTimer)window.clearTimeout(advanceTimer);if(countdownTimer)window.clearInterval(countdownTimer);closeDebate();gamePollTimer=null;advanceTimer=null;countdownTimer=null;if(root){root.hidden=true;root.innerHTML="";}currentUser=null;currentSessionId=null;currentPrefs=null;entry=null;factions=[];seats=[];factionManagement=[];factionActionStatus=[];gameState=null;selectedFactionId=null;switchingFaction=false;}
