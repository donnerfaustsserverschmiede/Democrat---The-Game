export const LEGAL_CONFIG = {
  version: "1.0",
  effectiveDate: "2026-09-29",
  operator: {
    name: "Paul Rühlemann",
    address: "Carl-Zeiss-Straße 27, 99097 Erfurt, Deutschland",
    email: "mafiatherealworld@gmail.com",
    privacyEmail: "mafiatherealworld@gmail.com"
  },
  game: {
    name: "Democrat – The Game",
    website: "",
    minimumAge: ""
  },
  services: {
    supabase: "Supabase (Authentifizierung und Datenbank)",
    hosting: "GitHub Pages bzw. der jeweils eingesetzte Hosting-/Auslieferungsdienst"
  }
};

export const legalIsReleaseReady = () =>
  Boolean(
    LEGAL_CONFIG.operator.name &&
    LEGAL_CONFIG.operator.address &&
    LEGAL_CONFIG.operator.email &&
    LEGAL_CONFIG.operator.privacyEmail
  );
