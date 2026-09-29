export const LEGAL_CONFIG = {
  version: "1.0",
  effectiveDate: "2026-09-29",

  operator: {
    name: "[VOLLSTÄNDIGER NAME / FIRMA EINTRAGEN]",
    address: "[STRASSE UND HAUSNUMMER], [PLZ] [ORT], Deutschland",
    email: "[KONTAKT-E-MAIL EINTRAGEN]",
    privacyEmail: "[DATENSCHUTZ-E-MAIL EINTRAGEN]",
    phone: "[TELEFON EINTRAGEN ODER ENTFERNEN]",
    vatId: "[UST-ID, FALLS VORHANDEN, EINTRAGEN ODER ENTFERNEN]",
    register: "[HANDELS-/VEREINSREGISTER, FALLS VORHANDEN, EINTRAGEN ODER ENTFERNEN]"
  },

  game: {
    name: "Democrat – The Game",
    website: "[PRODUKTIVE SPIEL-URL EINTRAGEN]",
    minimumAge: "[MINDESTALTER FESTLEGEN]"
  },

  services: {
    supabase: "Supabase (Authentifizierung und Datenbank)",
    hosting: "GitHub Pages bzw. der jeweils eingesetzte Hosting-/Auslieferungsdienst"
  }
};

export const legalIsReleaseReady = () =>
  Object.values(LEGAL_CONFIG.operator).every(
    (value) => value && !value.startsWith("[")
  ) &&
  LEGAL_CONFIG.game.website &&
  !LEGAL_CONFIG.game.website.startsWith("[") &&
  LEGAL_CONFIG.game.minimumAge &&
  !LEGAL_CONFIG.game.minimumAge.startsWith("[");
