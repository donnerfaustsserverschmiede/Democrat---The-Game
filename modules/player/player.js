import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

let supabase=null;
let currentUser=null;
let overlay=null;

const esc=v=>String(v??"").replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;").replaceAll("'","&#039;");
const money=v=>new Intl.NumberFormat("de-DE").format(Number(v||0))+" €";
const pct=v=>Number(v||0).toLocaleString("de-DE",{minimumFractionDigits:0,maximumFractionDigits:1})+" %";

export function init({client,user,target}){supabase=client;currentUser=user;overlay=target;}

function close(){if(overlay){overlay.hidden=true;overlay.innerHTML="";}}

export async function open(){
  if(!overlay||!supabase)return;
  overlay.hidden=false;
  overlay.innerHTML=`<section class="overview-panel player-panel"><button class="overview-panel-close" data-close type="button">×</button><div class="player-loading">Profil wird geladen …</div></section>`;
  overlay.querySelector("[data-close]")?.addEventListener("click",close);

  const {data,error}=await supabase.rpc("get_player_profile");
  if(error){
    overlay.querySelector(".player-loading").innerHTML=`<div class="overview-error">Profil konnte nicht geladen werden.<br><small>${esc(error.message)}</small></div>`;
    return;
  }
  const p=data?.[0];
  if(!p){
    overlay.querySelector(".player-loading").textContent="Kein Spielerprofil gefunden.";
    return;
  }

  const level=Number(p.level||1);
  overlay.innerHTML=`
    <section class="overview-panel player-panel">
      <button class="overview-panel-close" data-close type="button">×</button>
      <div class="player-heading">
        <div><span class="player-kicker">POLITISCHES PROFIL</span><h2>${esc(p.profile_name)}</h2><span class="player-level">Level ${level}</span></div>
        <div class="player-opinion-ring"><strong>${pct(p.public_opinion)}</strong><span>Volkesmeinung</span></div>
      </div>
      <div class="player-stat-grid">
        <article><span>Eigenes Geld</span><strong>${money(p.money)}</strong><small>Summe deiner aktiven Sitzungen</small></article>
        <article><span>Sitzungen</span><strong>${Number(p.sessions_participated||0)}</strong><small>Teilnahmen insgesamt</small></article>
        <article><span>Gewonnen</span><strong>${Number(p.sessions_won||0)}</strong><small>persönlich</small></article>
        <article><span>Fraktionssiege</span><strong>${Number(p.faction_wins||0)}</strong><small>mit deiner Fraktion</small></article>
      </div>
      <div class="player-decision-box">
        <div class="player-decision-head"><h3>Entscheidungsbilanz</h3><span>${Number(p.decisions||0)} Entscheidungen</span></div>
        <div class="player-bars">
          <div><span>Gemeinwohlfördernd</span><strong>${Number(p.good_decisions||0)}</strong></div>
          <div><span>Gemeinwohlschädigend</span><strong>${Number(p.bad_decisions||0)}</strong></div>
        </div>
        <p class="overview-panel-muted">Die Volksmeinung wird aus deinen tatsächlichen Abstimmungen und deren Bürgerwirkung über deine abgeschlossenen Sitzungen berechnet.</p>
      </div>
      <div class="player-level-box">
        <h3>Politischer Aufstieg</h3>
        <p>Level ${level}. Für die nächste Stufe zählt eine weitere abgeschlossene Sitzung.</p>
      </div>
    </section>`;
  overlay.querySelector("[data-close]")?.addEventListener("click",close);
}
