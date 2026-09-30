import { LEGAL_CONFIG, legalIsReleaseReady } from "./legal-config.js";
import { LEGAL_DOCUMENTS } from "./legal-documents.js";

const legal = document.querySelector("#legal-app");
const CONSENT_KEY = "democrat_legal_consent_v2";

function showAuth() {
  legal.classList.add("legal-fade-out");
  window.setTimeout(() => {
    legal.remove();
    const auth = document.querySelector("#auth-app");
    auth.hidden = false;
    const script = document.createElement("script");
    script.type = "module";
    script.src = "./modules/auth/auth.js?v=20260930-5";
    document.body.appendChild(script);
  }, 350);
}

function renderDocument(type) {
  const doc = LEGAL_DOCUMENTS[type];
  const modal = legal.querySelector("#legal-modal");
  modal.innerHTML = `
    <div class="legal-modal-backdrop" data-close-modal></div>
    <article class="legal-modal-card" role="dialog" aria-modal="true" aria-labelledby="legal-modal-title">
      <button class="legal-modal-close" type="button" data-close-modal aria-label="Schließen">×</button>
      <div class="legal-brand">DEMOCRAT – THE GAME · FASSUNG ${LEGAL_CONFIG.version}</div>
      <h2 id="legal-modal-title">${doc.title}</h2>
      <div class="legal-document-body">${doc.html}</div>
    </article>
  `;
  modal.hidden = false;
  modal.querySelectorAll("[data-close-modal]").forEach((el) =>
    el.addEventListener("click", () => { modal.hidden = true; modal.innerHTML = ""; })
  );
}

if (localStorage.getItem(CONSENT_KEY) === "accepted" && legalIsReleaseReady()) {
  showAuth();
} else {
  legal.hidden = false;
  const releaseReady = legalIsReleaseReady();

  legal.innerHTML = `
    <div class="legal-screen">
      <section class="legal-card" aria-labelledby="legal-title">
        <div class="legal-brand">DONNERFAUST GAMING</div>
        <h1 id="legal-title">Willkommen bei Democrat</h1>
        <p class="legal-intro">
          Bevor du das Spiel zum ersten Mal betrittst, erhältst du hier die rechtlichen Informationen zur Nutzung des Spiels.
        </p>

        <div class="legal-documents">
          <button type="button" class="legal-document" data-document="privacy">
            <span>Datenschutzerklärung</span><strong>›</strong>
          </button>
          <button type="button" class="legal-document" data-document="terms">
            <span>Nutzungsbedingungen</span><strong>›</strong>
          </button>
          <button type="button" class="legal-document" data-document="imprint">
            <span>Impressum</span><strong>›</strong>
          </button>
        </div>

        <div class="legal-checks">
          <label><input type="checkbox" data-check="privacy"><span>Ich habe die Datenschutzerklärung gelesen und zur Kenntnis genommen.</span></label>
          <label><input type="checkbox" data-check="terms"><span>Ich habe die Nutzungsbedingungen gelesen und akzeptiere sie.</span></label>
          <label><input type="checkbox" data-check="imprint"><span>Ich habe das Impressum zur Kenntnis genommen.</span></label>
        </div>

        <p class="legal-version">Fassung ${LEGAL_CONFIG.version} · Stand ${LEGAL_CONFIG.effectiveDate}</p>

        ${releaseReady ? "" : `
          <div class="legal-blocked">
            <strong>Veröffentlichung noch nicht freigegeben</strong>
            <span>Die Betreiber- und Kontaktdaten müssen vor dem produktiven Einsatz vollständig hinterlegt werden.</span>
          </div>
        `}

        <button type="button" id="legal-continue" class="legal-continue" disabled>
          Bestätigen &amp; fortfahren
        </button>
        <p id="legal-error" class="legal-error" role="alert" hidden></p>
      </section>
      <div id="legal-modal" class="legal-modal" hidden></div>
    </div>
  `;

  const checks = [...legal.querySelectorAll("[data-check]")];
  const continueButton = legal.querySelector("#legal-continue");
  const error = legal.querySelector("#legal-error");

  function updateButton() {
    continueButton.disabled = !releaseReady || !checks.every((check) => check.checked);
    error.hidden = true;
  }

  checks.forEach((check) => check.addEventListener("change", updateButton));
  legal.querySelectorAll("[data-document]").forEach((button) => {
    button.addEventListener("click", () => renderDocument(button.dataset.document));
  });

  continueButton.addEventListener("click", () => {
    if (!releaseReady) {
      error.textContent = "Die rechtlichen Angaben sind noch nicht vollständig eingerichtet.";
      error.hidden = false;
      return;
    }
    if (!checks.every((check) => check.checked)) {
      error.textContent = "Bitte bestätige alle drei Punkte.";
      error.hidden = false;
      return;
    }
    localStorage.setItem(CONSENT_KEY, "accepted");
    showAuth();
  });
}
