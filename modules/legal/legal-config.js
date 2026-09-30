export const LEGAL_CONFIG = {
  version: "1.1",
  effectiveDate: "2026-09-29",
  operator: {
    name: "Paul Rühlemann",
    role: "Inhaber und alleiniger Entwickler",
    address: "Carl-Zeiss-Straße 27, 99097 Erfurt, Deutschland",
    email: "mafiatherealworld@gmail.com",
    privacyEmail: "mafiatherealworld@gmail.com"
  },
  game: {
    name: "Democrat – The Game",
    website: ""
  },
  services: {
    supabase: "Supabase (Authentifizierung und Datenbank)",
    hosting: "GitHub Pages"
  }
};

export const legalIsReleaseReady = () =>
  Boolean(
    LEGAL_CONFIG.operator.name &&
    LEGAL_CONFIG.operator.address &&
    LEGAL_CONFIG.operator.email &&
    LEGAL_CONFIG.operator.privacyEmail
  );
