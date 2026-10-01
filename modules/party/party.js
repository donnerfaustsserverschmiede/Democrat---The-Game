import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

let supabase=null,currentUser=null,overlay=null;

const esc=v=>String(v??"").replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;").replaceAll("'","&#039;");
const money=v=>new Intl.NumberFormat("de-DE").format(Number(v||0))+" €";
const pct=v=>Number(v||0).toLocaleString("de-DE",{minimumFractionDigits:0,maximumFractionDigits:1})+" %";

const upgradeLabels={
 membership_capacity:["Mitgliederplätze","Erhöht die maximale Mitgliederzahl um 5."],
 public_image:["Öffentlichkeitsarbeit","Erhöht die öffentliche Parteimeinung um 2 Prozentpunkte pro Stufe."],
 campaign_network:["Wahlkampfnetzwerk","Erhöht die tägliche Parteieinnahme um 250 € pro Stufe."],
 election_influence:["Wahleinfluss","Reservierter Ausbau für spätere Wahleinfluss-Mechaniken."]
};

export function init({client,user,target}){supabase=client;currentUser=user;overlay=target;}
function close(){if(overlay){overlay.hidden=true;overlay.innerHTML="";}}
function errorText(e){
 const m=String(e?.message||e||"");
 const map={party_level_required:"Du erreichst Level 10 erst nach weiteren abgeschlossenen Sitzungen.",already_in_party:"Du bist bereits Mitglied einer Partei.",party_full:"Diese Partei ist voll.",insufficient_party_treasury:"Die Parteikasse reicht dafür noch nicht aus.",upgrade_maxed:"Diese Verbesserung ist bereits auf dem Höchstlevel.",only_owner_can_appoint_deputy:"Nur der Vorsitzende kann einen Stellvertreter ernennen."};
 return map[m]||m;
}

async function loadOverview(){
 const [{data:mine,error:mineError},{data:profile,error:profileError}]=await Promise.all([
  supabase.rpc("get_my_party"),
  supabase.rpc("get_player_profile")
 ]);
 if(mineError)throw mineError;if(profileError)throw profileError;
 return {party:mine?.[0]||null,profile:profile?.[0]||null};
}

export async function open(){
 if(!overlay||!supabase)return;
 overlay.hidden=false;
 overlay.innerHTML=`<section class="overview-panel party-panel"><button class="overview-panel-close" data-close type="button">×</button><div class="party-loading">Partei wird geladen …</div></section>`;
 overlay.querySelector("[data-close]")?.addEventListener("click",close);
 try{
   const {party,profile}=await loadOverview();
   if(party) await renderOwnParty(party);
   else await renderPartyDirectory(profile);
 }catch(e){
   overlay.querySelector(".party-loading").innerHTML=`<div class="overview-error">Parteisystem konnte nicht geladen werden.<br><small>${esc(e.message)}</small></div>`;
 }
}

async function renderPartyDirectory(profile){
 const {data:parties,error}=await supabase.rpc("get_joinable_parties");if(error)throw error;
 const canCreate=Number(profile?.level||1)>=10;
 overlay.innerHTML=`
 <section class="overview-panel party-panel">
  <button class="overview-panel-close" data-close type="button">×</button>
  <div class="party-heading"><div><span class="party-kicker">POLITISCHE ORGANISATION</span><h2>Partei</h2></div><span class="party-level">Dein Level ${Number(profile?.level||1)}</span></div>
  <p class="overview-panel-muted">Ab Level 1 kannst du einer bestehenden Partei beitreten. Ab Level 10 kannst du selbst eine Partei gründen.</p>
  <div class="party-directory">${(parties||[]).length?(parties||[]).map(p=>`
    <article class="party-card"><div><strong>${esc(p.name)}</strong><span>${esc(p.tag)} · ${p.member_count}/${p.max_members} Mitglieder · ${pct(p.opinion)} Meinung</span></div><button class="overview-settings-save" data-join="${p.id}" type="button">Beitreten</button></article>`).join(""):`<div class="overview-empty">Aktuell sind keine beitretbaren Parteien vorhanden.</div>`}</div>
  ${canCreate?`<div class="party-create-box"><h3>Eigene Partei gründen</h3><form id="party-create-form" class="overview-settings-form"><label>Parteiname<input name="name" maxlength="40" minlength="3" required></label><label>Partei-Kürzel<input name="tag" maxlength="6" minlength="2" required></label><div id="party-create-message" class="overview-settings-message" hidden></div><button class="overview-settings-save" type="submit">Partei gründen</button></form></div>`:`<div class="party-lock">🔒 Eigene Partei gründen: ab Level 10</div>`}
 </section>`;
 overlay.querySelector("[data-close]")?.addEventListener("click",close);
 overlay.querySelectorAll("[data-join]").forEach(b=>b.addEventListener("click",async()=>{b.disabled=true;try{const {error}=await supabase.rpc("join_party",{p_party_id:b.dataset.join});if(error)throw error;await open();}catch(e){b.disabled=false;alert(errorText(e));}}));
 overlay.querySelector("#party-create-form")?.addEventListener("submit",async ev=>{
   ev.preventDefault();const f=new FormData(ev.currentTarget);const msg=overlay.querySelector("#party-create-message");const btn=ev.currentTarget.querySelector("button");btn.disabled=true;
   try{const {error}=await supabase.rpc("create_party",{p_name:String(f.get("name")||""),p_tag:String(f.get("tag")||"")});if(error)throw error;await open();}
   catch(e){msg.hidden=false;msg.className="overview-settings-message error";msg.textContent=errorText(e);btn.disabled=false;}
 });
}

async function renderOwnParty(party){
 const [mg,mem,ups]=await Promise.all([
  supabase.rpc("get_party_management",{p_party_id:party.id}),
  supabase.rpc("get_party_members",{p_party_id:party.id}),
  supabase.rpc("get_party_upgrades",{p_party_id:party.id})
 ]);
 if(mg.error)throw mg.error;if(mem.error)throw mem.error;if(ups.error)throw ups.error;
 const p=mg.data?.[0]||party,members=mem.data||[],upgrades=ups.data||[];
 const canManage=party.role==="owner"||party.role==="deputy",isOwner=party.role==="owner";
 overlay.innerHTML=`
 <section class="overview-panel party-panel">
  <button class="overview-panel-close" data-close type="button">×</button>
  <div class="party-heading"><div><span class="party-kicker">PARTEI-DASHBOARD</span><h2>${esc(p.name)} <small>${esc(p.tag)}</small></h2><span class="party-role">${isOwner?"Vorsitzender":party.role==="deputy"?"Stellvertreter":"Mitglied"}</span></div><div class="party-opinion"><strong>${pct(p.opinion)}</strong><span>Parteimeinung</span></div></div>
  <div class="party-stat-grid"><article><span>Parteikasse</span><strong>${money(p.treasury)}</strong></article><article><span>Mitglieder</span><strong>${p.member_count}/${p.max_members}</strong></article><article><span>Tägliche Einnahmen</span><strong>${money(p.daily_income)}</strong><small>500 € je Mitglied + Ausbauten</small></article><article><span>Parteilevel</span><strong>${p.level}</strong></article></div>
  <section class="party-section"><div class="party-section-head"><h3>Mitglieder</h3><span>${members.length} Mitglieder</span></div><div class="party-members">${members.map(m=>`
   <article class="party-member"><div><strong>${esc(m.profile_name)}</strong><span>${m.role==="owner"?"Vorsitzender":m.role==="deputy"?"Stellvertreter":"Mitglied"} · ${pct(m.public_opinion)} Volksmeinung</span></div><div class="party-member-actions">
    ${isOwner&&m.role!=="owner"?`<button data-deputy="${m.user_id}" type="button">${m.role==="deputy"?"Stellvertreter":"Zum Stellvertreter"}</button>`:""}
    ${canManage&&m.role!=="owner"&&!(party.role==="deputy"&&m.role==="deputy")?`<button data-kick="${m.user_id}" class="danger" type="button">Kicken</button>`:""}
   </div></article>`).join("")}</div>${!isOwner?`<button class="party-leave" data-leave type="button">Partei verlassen</button>`:""}</section>
  <section class="party-section"><div class="party-section-head"><h3>Rangliste</h3><span>Volksmeinung</span></div>
   <div class="party-ranking-tabs"><button class="party-tab active" data-tab="players" type="button">Parteispieler</button><button class="party-tab" data-tab="parties" type="button">Parteien</button></div>
   <div id="party-ranking-content" class="party-ranking-content">Rangliste wird geladen …</div>
  </section>
  <section class="party-section"><div class="party-section-head"><h3>Parteiaktionen</h3><span>Ausbauten aus der Parteikasse</span></div><div class="party-upgrades">${upgrades.map(u=>`
   <article class="party-upgrade"><div><strong>${esc(u.display_name)}</strong><span>${esc(u.description)}</span><small>Stufe ${u.level}/${u.max_level} · Nächste Kosten: ${u.next_cost?money(u.next_cost):"MAX"}</small></div><button data-upgrade="${u.code}" type="button" ${!canManage||!u.next_cost?"disabled":""}>Ausbauen</button></article>`).join("")}</div>
  </section>
  ${canManage?`<section class="party-section"><div class="party-section-head"><h3>Verwaltung</h3><span>Vorsitzender & Stellvertreter</span></div>
   <form id="party-settings-form" class="overview-settings-form party-admin-form">
    <label>Parteiname<input name="name" value="${esc(p.name)}" maxlength="40" minlength="3" required></label>
    <label>Tag<input name="tag" value="${esc(p.tag)}" maxlength="6" minlength="2" required></label>
    <label>Farbe<input name="color" value="${esc(p.color||"#2e78ff")}" pattern="#[0-9A-Fa-f]{6}" required></label>
    <label>Logo<input name="logo" value="${esc(p.logo_path||"")}" maxlength="300" placeholder="Logo-URL oder Pfad"></label>
    <label>Beschreibung<textarea name="description" maxlength="500">${esc(p.description||"")}</textarea></label>
    <div id="party-admin-message" class="overview-settings-message" hidden></div>
    <button class="overview-settings-save" type="submit">Einstellungen speichern</button>
   </form>
   ${isOwner?`<div class="party-close-box"><strong>Partei schließen</strong><p>Alle Mitglieder werden parteilos und die Partei wird aus der Parteienliste entfernt.</p><button class="party-leave" data-close-party type="button">Partei endgültig schließen</button></div>`:""}
  </section>`:""}
 </section>`;
 overlay.querySelector("[data-close]")?.addEventListener("click",close);
 const rankContent=overlay.querySelector("#party-ranking-content");
 async function loadPlayerRanks(){const {data,error}=await supabase.rpc("get_party_player_rankings",{p_party_id:party.id});if(error){rankContent.innerHTML=`<div class="overview-error">${esc(error.message)}</div>`;return;}rankContent.innerHTML=(data||[]).map(x=>`<div class="party-rank-row"><strong>#${x.rank}</strong><span>${esc(x.profile_name)} <small>${x.role==="owner"?"Vorsitzender":x.role==="deputy"?"Stellvertreter":"Mitglied"}</small></span><b>${pct(x.public_opinion)}</b></div>`).join("")||'<div class="overview-panel-muted">Keine Mitglieder.</div>';}
 async function loadPartyRanks(){const {data,error}=await supabase.rpc("get_party_rankings");if(error){rankContent.innerHTML=`<div class="overview-error">${esc(error.message)}</div>`;return;}rankContent.innerHTML=(data||[]).map(x=>`<div class="party-rank-row"><strong>#${x.rank}</strong><span>${esc(x.party_name)} <small>${esc(x.party_tag)} · ${x.member_count} Mitglieder</small></span><b>${pct(x.party_opinion)}</b></div>`).join("")||'<div class="overview-panel-muted">Keine Parteien.</div>';}
 await loadPlayerRanks();
 overlay.querySelectorAll("[data-tab]").forEach(tab=>tab.addEventListener("click",async()=>{overlay.querySelectorAll("[data-tab]").forEach(x=>x.classList.remove("active"));tab.classList.add("active");if(tab.dataset.tab==="players")await loadPlayerRanks();else await loadPartyRanks();}));
 overlay.querySelectorAll("[data-deputy]").forEach(b=>b.addEventListener("click",async()=>{b.disabled=true;try{const {error}=await supabase.rpc("change_party_role",{p_party_id:party.id,p_member_id:b.dataset.deputy,p_role:"deputy"});if(error)throw error;await open();}catch(e){b.disabled=false;alert(errorText(e));}}));
 overlay.querySelectorAll("[data-kick]").forEach(b=>b.addEventListener("click",async()=>{b.disabled=true;try{const {error}=await supabase.rpc("kick_party_member",{p_party_id:party.id,p_member_id:b.dataset.kick});if(error)throw error;await open();}catch(e){b.disabled=false;alert(errorText(e));}}));
 overlay.querySelectorAll("[data-upgrade]").forEach(b=>b.addEventListener("click",async()=>{b.disabled=true;try{const {error}=await supabase.rpc("purchase_party_upgrade",{p_party_id:party.id,p_upgrade_code:b.dataset.upgrade});if(error)throw error;await open();}catch(e){b.disabled=false;alert(errorText(e));}}));
 overlay.querySelector("[data-leave]")?.addEventListener("click",async b=>{b.currentTarget.disabled=true;try{const {error}=await supabase.rpc("leave_party",{p_party_id:party.id});if(error)throw error;await open();}catch(e){b.currentTarget.disabled=false;alert(errorText(e));}});
 overlay.querySelector("#party-settings-form")?.addEventListener("submit",async ev=>{ev.preventDefault();const f=new FormData(ev.currentTarget),msg=overlay.querySelector("#party-admin-message"),btn=ev.currentTarget.querySelector("button");btn.disabled=true;try{const {error}=await supabase.rpc("update_party_settings",{p_party_id:party.id,p_name:String(f.get("name")||""),p_tag:String(f.get("tag")||""),p_color:String(f.get("color")||""),p_logo_path:String(f.get("logo")||""),p_description:String(f.get("description")||"")});if(error)throw error;await open();}catch(e){msg.hidden=false;msg.className="overview-settings-message error";msg.textContent=errorText(e);btn.disabled=false;}});
 overlay.querySelector("[data-close-party]")?.addEventListener("click",async b=>{if(!confirm("Partei wirklich endgültig schließen? Alle Mitglieder werden parteilos."))return;b.currentTarget.disabled=true;try{const {error}=await supabase.rpc("close_party",{p_party_id:party.id});if(error)throw error;await open();}catch(e){b.currentTarget.disabled=false;alert(errorText(e));}});
}
}
