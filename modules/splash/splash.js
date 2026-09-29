const splash = document.querySelector("#splash-app");
const auth = document.querySelector("#auth-app");

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
    auth.hidden = false;
    const script = document.createElement("script");
    script.type = "module";
    script.src = "./modules/auth/auth.js";
    document.body.appendChild(script);
  }, 500);
}, 2000);