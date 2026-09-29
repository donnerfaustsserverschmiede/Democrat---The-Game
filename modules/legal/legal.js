const legal = document.querySelector("#legal-app");
const CONSENT_KEY = "democrat_legal_consent_v1";

function showAuth() {
  legal.classList.add("legal-fade-out");
  window.setTimeout(() => {
    legal.remove();
    const auth = document.querySelector("#auth-app");
    auth.hidden = false;
    const script = document.createElement("script");
    script.type = "module";
    script.src = "./modules/auth/auth.js";
    document.body.appendChild(script);
  }, 350);
}

if (localStorage.getItem(CONSENT_KEY) === "accepted") {
  showAuth();
} else {
  legal.hidden = false;
  legal.innerHTML = `
    <div class="legal-screen">
      <section class="legal-card" aria-labelledby="legal-title">
        <div class="legal-brand">DONNERFAUST GAMING</div>
        <h1 id="legal-title">Willkommen bei Democrat</h1>
        <p class="legal-intro">
          Bevor du das Spiel zum ersten Mal betrittst, bestätige bitte die folgenden Hinweise.
        </p>

        <div class="legal-documents">
          <button type="button" class="legal-document" data-document="privacy">
            <span>Datenschutz &amp; Datennutzung</span><strong>›</strong>
          </button>
          <button type="button" class="legal-document" data-document="terms">
            <span>Nutzungsbedingungen</span><strong>›</strong>
          </button>
          <button type="button" class="legal-document" data-document="imprint">
            <span>Impressum</span><strong>›</strong>
          </button>
        </div>

        <div class="legal-checks">
          <label>
            <input type="checkbox" data-check="privacy">
            <span>Ich habe die Hinweise zu Datenschutz und Datennutzung gelesen und verstanden.</span>
          </label>
          <label>
            <input type="checkbox" data-check="terms">
            <span>Ich habe die Nutzungsbedingungen gelesen und akzeptiere sie.</span>
          </label>
          <label>
            <input type="checkbox" data-check="imprint">
            <span>Ich habe die Angaben im Impressum zur Kenntnis genommen.</span>
          </label>
        </div>

        <p class="legal-note">
          Die rechtlichen Dokumente werden vor dem produktiven Release mit den vollständigen Betreiberangaben und endgültigen Rechtstexten hinterlegt.
        </p>

        <button type="button" id="legal-continue" class="legal-continue" disabled>
          Bestätigen &amp; fortfahren
        </button>
        <p id="legal-error" class="legal-error" role="alert" hidden></p>
      </section>
    </div>
  `;

  const checks = [...legal.querySelectorAll("[data-check]")];
  const continueButton = legal.querySelector("#legal-continue");
  const error = legal.querySelector("#legal-error");

  function updateButton() {
    continueButton.disabled = !checks.every((check) => check.checked);
    error.hidden = true;
  }

  checks.forEach((check) => check.addEventListener("change", updateButton));

  legal.querySelectorAll("[data-document]").forEach((button) => {
    button.addEventListener("click", () => {
      const type = button.dataset.document;
      const titles = {
        privacy: "Datenschutz & Datennutzung",
        terms: "Nutzungsbedingungen",
        imprint: "Impressum"
      };
      alert(`${titles[type]}\n\nDer vollständige Rechtstext wird hier vor dem produktiven Release hinterlegt.`);
    });
  });

  continueButton.addEventListener("click", () => {
    if (!checks.every((check) => check.checked)) {
      error.textContent = "Bitte bestätige alle drei Punkte.";
      error.hidden = false;
      return;
    }

    localStorage.setItem(CONSENT_KEY, "accepted");
    showAuth();
  });
}