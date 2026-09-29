const splash = document.querySelector("#splash-app");
const legal = document.querySelector("#legal-app");

splash.innerHTML = `
  <div class="splash-screen" role="status" aria-label="Donnerfaust Gaming">
    <div class="splash-content">
      <div class="splash-title">DONNERFAUST</div>
      <div class="splash-subtitle">GAMING</div>
    </div>
  </div>
`;

window.setTimeout(() => {
  splash.classList.add("splash-fade-out");
  window.setTimeout(() => {
    splash.remove();

    const script = document.createElement("script");
    script.type = "module";
    script.src = "./modules/legal/legal.js";
    document.body.appendChild(script);
  }, 500);
}, 2000);