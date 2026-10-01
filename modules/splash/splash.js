const splash = document.querySelector("#splash-app");

splash.innerHTML = `
  <div class="splash-sequence" role="status" aria-label="Democrat – The Game">
    <div class="publisher-splash">
      <div class="publisher-mark">DONNERFAUST</div>
      <div class="publisher-sub">INTERACTIVE</div>
    </div>
    <div class="game-splash">
      <img class="game-logo splash-logo" src="./assets/democrat-logo.svg?v=20261001-2" alt="Democrat – The Game">
    </div>
    <div class="splash-error" hidden>
      <strong>Democrat – The Game</strong>
      <span>Das Spiel konnte nicht geladen werden.</span>
      <button type="button" data-reload>Neu laden</button>
    </div>
  </div>
`;

const sequence = splash.querySelector(".splash-sequence");
const publisher = splash.querySelector(".publisher-splash");
const game = splash.querySelector(".game-splash");
const errorBox = splash.querySelector(".splash-error");

function showError(error){
  console.error("[Democrat] Boot error:", error);
  publisher.hidden = true;
  game.hidden = true;
  errorBox.hidden = false;
}

splash.querySelector("[data-reload]")?.addEventListener("click",()=>window.location.reload());

async function boot(){
  try {
    await new Promise(resolve=>window.setTimeout(resolve, 1200));
    publisher.classList.add("publisher-out");
    await new Promise(resolve=>window.setTimeout(resolve, 450));
    publisher.hidden = true;

    game.hidden = false;
    game.classList.add("game-in");
    await new Promise(resolve=>window.setTimeout(resolve, 1400));

    const module = await import("./../legal/legal.js?v=20261001-2");
    void module;

    // Keep the splash up until the next application layer is actually visible.
    const legal = document.querySelector("#legal-app");
    const auth = document.querySelector("#auth-app");
    const overview = document.querySelector("#overview-app");
    const session = document.querySelector("#session-app");

    const ready = () => Boolean(
      (legal && !legal.hidden) ||
      (auth && !auth.hidden) ||
      (overview && !overview.hidden) ||
      (session && !session.hidden)
    );

    if(!ready()){
      await new Promise(resolve=>window.setTimeout(resolve, 800));
    }

    sequence.classList.add("splash-fade-out");
    await new Promise(resolve=>window.setTimeout(resolve, 500));
    splash.remove();
  } catch(error) {
    showError(error);
  }
}

boot();
