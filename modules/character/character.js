import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "../auth/auth-config-v2.js?v=20261005-1";
import * as country from "../country/country.js?v=20261005-1";

const root = document.querySelector("#character-app");
let supabase = null;
let currentUser = null;

const OPTIONS = {
  hairstyle: [
    ["short","Kurz"],["side","Seitenscheitel"],["slick","Zurückgekämmt"],["medium","Mittellang"],["curly","Lockig"],["buzz","Sehr kurz"],["bald","Glatze"]
  ],
  hairColor: [
    ["black","Schwarz"],["dark-brown","Dunkelbraun"],["brown","Braun"],["blond","Blond"],["red","Rot"],["gray","Grau"],["white","Weiß"]
  ],
  eyeColor: [
    ["blue","Blau"],["green","Grün"],["brown","Braun"],["gray","Grau"]
  ],
  suit: [
    ["navy","Dunkelblau"],["black","Schwarz"],["charcoal","Anthrazit"],["gray","Grau"],["modern","Modern Blau"]
  ],
  tieColor: [
    ["blue","Blau"],["red","Rot"],["green","Grün"],["gold","Gold"],["purple","Violett"],["black","Schwarz"],["silver","Silber"],["orange","Orange"]
  ]
};

const DEFAULTS = {
  hairstyle:"side",
  hairColor:"dark-brown",
  eyeColor:"blue",
  suit:"navy",
  tieColor:"blue"
};

function escapeHtml(value) {
  return String(value).replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;").replaceAll("'","&#039;");
}

function selectOptions(items, selected) {
  return items.map(([value,label]) => '<option value="'+value+'"'+(value===selected?' selected':'')+'>'+label+'</option>').join("");
}

function normalizeCharacter(raw) {
  return {
    firstName: String(raw?.firstName || "").trim(),
    lastName: String(raw?.lastName || "").trim(),
    hairstyle: OPTIONS.hairstyle.some(([v])=>v===raw?.hairstyle) ? raw.hairstyle : DEFAULTS.hairstyle,
    hairColor: OPTIONS.hairColor.some(([v])=>v===raw?.hairColor) ? raw.hairColor : DEFAULTS.hairColor,
    eyeColor: OPTIONS.eyeColor.some(([v])=>v===raw?.eyeColor) ? raw.eyeColor : DEFAULTS.eyeColor,
    suit: OPTIONS.suit.some(([v])=>v===raw?.suit) ? raw.suit : DEFAULTS.suit,
    tieColor: OPTIONS.tieColor.some(([v])=>v===raw?.tieColor) ? raw.tieColor : DEFAULTS.tieColor
  };
}

function hasCharacter(user) {
  const c = user?.user_metadata?.character;
  return Boolean(c?.firstName?.trim() && c?.lastName?.trim());
}

function render(character = {}) {
  const c = normalizeCharacter(character);
  root.hidden = false;
  root.innerHTML = `
    <div class="character-shell">
      <section class="character-card">
        <div class="character-kicker">DEMOCRAT · DEINE POLITISCHE FIGUR</div>
        <h1>Erstelle deinen Charakter</h1>
        <p class="character-intro">Gestalte die Person, mit der du deine politische Karriere beginnst.</p>

        <div class="character-layout">
          <form id="character-form" class="character-form">
            <div class="character-section">
              <h2>Name</h2>
              <div class="character-name-grid">
                <label>Vorname
                  <input name="firstName" type="text" maxlength="32" autocomplete="given-name" value="${escapeHtml(c.firstName)}" required>
                </label>
                <label>Nachname
                  <input name="lastName" type="text" maxlength="32" autocomplete="family-name" value="${escapeHtml(c.lastName)}" required>
                </label>
              </div>
            </div>

            <div class="character-section">
              <h2>Aussehen</h2>
              <div class="character-option-grid">
                <label>Frisur<select name="hairstyle">${selectOptions(OPTIONS.hairstyle,c.hairstyle)}</select></label>
                <label>Haarfarbe<select name="hairColor">${selectOptions(OPTIONS.hairColor,c.hairColor)}</select></label>
                <label>Augenfarbe<select name="eyeColor">${selectOptions(OPTIONS.eyeColor,c.eyeColor)}</select></label>
              </div>
            </div>

            <div class="character-section">
              <h2>Kleidung</h2>
              <div class="character-option-grid">
                <label>Anzug<select name="suit">${selectOptions(OPTIONS.suit,c.suit)}</select></label>
                <label>Krawatte<select name="tieColor">${selectOptions(OPTIONS.tieColor,c.tieColor)}</select></label>
              </div>
            </div>

            <p id="character-message" class="character-message" role="alert" hidden></p>
            <button class="character-save" type="submit">Charakter erstellen</button>
          </form>

          <aside class="character-preview-panel" aria-label="Charaktervorschau">
            <div class="character-preview">
              <div class="avatar">
                <div class="avatar-hair"></div>
                <div class="avatar-head"><span class="avatar-eye avatar-eye-left"></span><span class="avatar-eye avatar-eye-right"></span></div>
                <div class="avatar-neck"></div>
                <div class="avatar-body"><div class="avatar-shirt"></div><div class="avatar-tie"></div></div>
              </div>
              <div id="character-preview-name" class="character-preview-name"></div>
            </div>
          </aside>
        </div>
      </section>
    </div>
  `;

  const form = root.querySelector("#character-form");
  const previewName = root.querySelector("#character-preview-name");
  const message = root.querySelector("#character-message");

  function updatePreview() {
    const data = Object.fromEntries(new FormData(form).entries());
    root.querySelector(".avatar").dataset.hairstyle = data.hairstyle;
    root.querySelector(".avatar").dataset.haircolor = data.hairColor;
    root.querySelector(".avatar").dataset.eyecolor = data.eyeColor;
    root.querySelector(".avatar").dataset.suit = data.suit;
    root.querySelector(".avatar").dataset.tie = data.tieColor;
    previewName.textContent = [data.firstName,data.lastName].filter(Boolean).join(" ");
  }

  form.addEventListener("input", updatePreview);
  form.addEventListener("change", updatePreview);
  form.addEventListener("submit", saveCharacter);
  updatePreview();
}

async function saveCharacter(event) {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  const character = normalizeCharacter({
    firstName: form.get("firstName"),
    lastName: form.get("lastName"),
    hairstyle: form.get("hairstyle"),
    hairColor: form.get("hairColor"),
    eyeColor: form.get("eyeColor"),
    suit: form.get("suit"),
    tieColor: form.get("tieColor")
  });

  const message = root.querySelector("#character-message");
  if (character.firstName.length < 2 || character.lastName.length < 2) {
    message.textContent = "Vor- und Nachname müssen jeweils mindestens 2 Zeichen lang sein.";
    message.hidden = false;
    return;
  }

  const button = root.querySelector(".character-save");
  button.disabled = true;
  message.hidden = true;

  const { data, error } = await supabase.auth.updateUser({ data: { character } });
  if (error) {
    console.error("[Democrat] Character save error:", error);
    message.textContent = "Der Charakter konnte nicht gespeichert werden. Bitte versuche es erneut.";
    message.hidden = false;
    button.disabled = false;
    return;
  }

  currentUser = data?.user || currentUser;
  root.hidden = true;
  await country.mount(currentUser);
}

export async function mount(user) {
  currentUser = user;
  if (!root) return;
  if (!SUPABASE_PUBLISHABLE_KEY || SUPABASE_PUBLISHABLE_KEY.startsWith("REPLACE_")) {
    root.hidden = false;
    root.innerHTML = '<div class="character-shell"><section class="character-card"><h1>Charaktererstellung</h1><p>Supabase ist noch nicht konfiguriert.</p></section></div>';
    return;
  }
  supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
  const existing = user?.user_metadata?.character;
  render(existing || {});
}

export function hasExistingCharacter(user) {
  return hasCharacter(user);
}
