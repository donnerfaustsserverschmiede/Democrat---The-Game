const splash = document.querySelector("#splash-app");

splash.innerHTML = `
  <div class="splash-screen" role="status" aria-label="Democrat – The Game">
    <div class="splash-content">
      <div class="splash-kicker">DONNERFAUST GAMING PRÄSENTIERT</div>
      <div class="splash-title">DEMOCRAT</div>
      <div class="splash-subtitle">THE GAME</div>
      <div class="splash-rule"></div>
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
