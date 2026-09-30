import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "../auth/auth-config-v2.js?v=20260930-3";

const root = document.querySelector("#country-app");
let supabase = null;
let currentUser = null;

function escapeHtml(value) {
  return String(value).replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;").replaceAll("'","&#039;");
}

function labels(locale = "de-DE") {
  const map = {  // Country names stay in each country's own language; the UI is localized after selection.

    "de-DE": { title:"Wähle dein Land", text:"Dein Land bestimmt die Sprache des Spiels und welche politischen Institutionen und Sitzungen dir zur Verfügung stehen.", language:"Sprache", form:"Regierungsform", choose:"Land auswählen", save:"Auswahl bestätigen", loading:"Länder werden geladen …", error:"Die Länderauswahl konnte nicht geladen werden." },
    "de-AT": { title:"Wähle dein Land", text:"Dein Land bestimmt die Sprache des Spiels und die passenden politischen Institutionen und Sitzungen.", language:"Sprache", form:"Staatsform", choose:"Land auswählen", save:"Auswahl bestätigen", loading:"Länder werden geladen …", error:"Die Länderauswahl konnte nicht geladen werden." },
    "de-CH": { title:"Wähle dein Land", text:"Dein Land bestimmt die Sprache des Spiels und die passenden politischen Institutionen und Sitzungen.", language:"Sprache", form:"Staatsform", choose:"Land auswählen", save:"Auswahl bestätigen", loading:"Länder werden geladen …", error:"Die Länderauswahl konnte nicht geladen werden." },
    "es-ES": { title:"Elige tu país", text:"Tu país determina el idioma del juego y las instituciones y sesiones políticas disponibles.", language:"Idioma", form:"Forma de gobierno", choose:"Seleccionar país", save:"Confirmar selección", loading:"Cargando países …", error:"No se pudo cargar la selección de país." },
    "es-MX": { title:"Elige tu país", text:"Tu país determina el idioma del juego y las instituciones y sesiones políticas disponibles.", language:"Idioma", form:"Forma de gobierno", choose:"Seleccionar país", save:"Confirmar selección", loading:"Cargando países …", error:"No se pudo cargar la selección de país." },
    "fr-FR": { title:"Choisissez votre pays", text:"Votre pays détermine la langue du jeu ainsi que les institutions et sessions politiques disponibles.", language:"Langue", form:"Régime", choose:"Choisir le pays", save:"Confirmer la sélection", loading:"Chargement des pays …", error:"Impossible de charger la sélection du pays." },
    "it-IT": { title:"Scegli il tuo paese", text:"Il tuo paese determina la lingua del gioco e le istituzioni e sessioni politiche disponibili.", language:"Lingua", form:"Forma di governo", choose:"Seleziona paese", save:"Conferma selezione", loading:"Caricamento dei paesi …", error:"Impossibile caricare la selezione del paese." },
    "pt-BR": { title:"Escolha seu país", text:"Seu país determina o idioma do jogo e as instituições e sessões políticas disponíveis.", language:"Idioma", form:"Forma de governo", choose:"Selecionar país", save:"Confirmar seleção", loading:"Carregando países …", error:"Não foi possível carregar a seleção do país." },
    "en-US": { title:"Choose your country", text:"Your country determines the game language and the political institutions and sessions available to you.", language:"Language", form:"Government", choose:"Select country", save:"Confirm selection", loading:"Loading countries …", error:"The country selection could not be loaded." },
    "en-GB": { title:"Choose your country", text:"Your country determines the game language and the political institutions and sessions available to you.", language:"Language", form:"Government", choose:"Select country", save:"Confirm selection", loading:"Loading countries …", error:"The country selection could not be loaded." },
    "en-CA": { title:"Choose your country", text:"Your country determines the game language and the political institutions and sessions available to you.", language:"Language", form:"Government", choose:"Select country", save:"Confirm selection", loading:"Loading countries …", error:"The country selection could not be loaded." },
    "en-AU": { title:"Choose your country", text:"Your country determines the game language and the political institutions and sessions available to you.", language:"Language", form:"Government", choose:"Select country", save:"Confirm selection", loading:"Loading countries …", error:"The country selection could not be loaded." }
  };
  return map[locale] || map["de-DE"];
}

async function showOverview(user, prefs) {
  root.hidden = true;
  const overview = await import("../overview/overview.js?v=20260930-5");
  await overview.mount(user, prefs);
}

const FLAG_BY_COUNTRY = {DE:"🇩🇪",ES:"🇪🇸",FR:"🇫🇷",IT:"🇮🇹",US:"🇺🇸",GB:"🇬🇧",AT:"🇦🇹",CH:"🇨🇭",CA:"🇨🇦",AU:"🇦🇺",BR:"🇧🇷",MX:"🇲🇽"};

function render(countries, currentLocale = "de-DE", message = "") {
  const t = labels(currentLocale);
  root.hidden = false;
  root.innerHTML = `
    <div class="country-shell">
      <section class="country-card">
        <div class="country-kicker">DEMOKRATIE · THE GAME</div>
        <h1>${t.title}</h1>
        <p class="country-description">${t.text}</p>
        ${message ? `<div class="country-message">${escapeHtml(message)}</div>` : ""}
        <div class="country-grid">
          ${countries.map(country => `
            <button type="button" class="country-option" data-country="${country.code}">
              <span class="country-name"><span class="country-flag" aria-hidden="true">${FLAG_BY_COUNTRY[country.code] || "🌐"}</span>${escapeHtml(country.display_name)}</span>
              <span class="country-meta">${escapeHtml(country.language_name)} · ${escapeHtml(country.government_name)}</span>
            </button>
          `).join("")}
        </div>
        <div class="country-note">Die Auswahl steuert die Sprache und die landesspezifischen Sitzungen. Du kannst sie später in deinem Profil ändern.</div>
      </section>
    </div>
  `;

  root.querySelectorAll("[data-country]").forEach(button => {
    button.addEventListener("click", () => saveCountry(button.dataset.country, countries));
  });
}

async function saveCountry(code, countries) {
  root.querySelectorAll("[data-country]").forEach(button => button.disabled = true);
  const { data, error } = await supabase.rpc("set_country_preferences", { p_country_code: code });
  if (error) {
    render(countries, "de-DE", "Die Auswahl konnte nicht gespeichert werden. Bitte versuche es erneut.");
    return;
  }
  await showOverview(currentUser, data?.[0] || null);
}

export async function mount(user) {
  currentUser = user;
  if (!SUPABASE_PUBLISHABLE_KEY || SUPABASE_PUBLISHABLE_KEY.startsWith("REPLACE_")) return;
  supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);

  const { data: prefData } = await supabase.rpc("get_country_preferences");
  const prefs = prefData?.[0] || null;
  if (prefs?.country_code) {
    await showOverview(user, prefs);
    return;
  }

  const { data: countries, error } = await supabase.rpc("get_available_countries");
  if (error) {
    render([], "de-DE", labels("de-DE").error);
    return;
  }
  render(countries || []);
}
