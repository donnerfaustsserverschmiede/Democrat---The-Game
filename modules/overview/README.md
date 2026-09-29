# Overview / Sitzungen

Dieses Modul ist die erste Übersicht nach erfolgreicher Anmeldung.

## Zuständigkeit

- HUD der Startübersicht
- MEINE SITZUNGEN
- ÖFFENTLICHE SITZUNGEN
- Anzeige der belegten Plätze
- Beitritt zu öffentlichen Sitzungen
- Übergang vom Auth-Modul in die Übersicht

## Sitzungsregeln

- Jede Sitzung hat maximal 30 Plätze.
- Volle Sitzungen erscheinen nicht mehr unter ÖFFENTLICHE SITZUNGEN.
- Volle Sitzungen bleiben unter MEINE SITZUNGEN für bereits teilnehmende Spieler sichtbar.
- Sobald eine Sitzung voll ist, wird automatisch die nächste leere Sitzung desselben Sitzungstyps erzeugt.
- Sitzungstypen können unabhängig erweitert werden, z. B. Landtag, Bundestag und später weitere politische Sitzungsarten.

## Architektur

Das Modul greift nicht direkt auf die internen Sitzungstabellen zu. Die Kommunikation erfolgt ausschließlich über definierte Supabase-RPC-Schnittstellen:

- `get_my_sessions()`
- `get_public_sessions()`
- `join_session(uuid)`
- `leave_session(uuid)`

Die eigentlichen Tabellen und die Platz-/Voll-Logik liegen im getrennten `game`-Datenbereich.

## Abgrenzung

Dieses Modul enthält keine Partei-, Wahl-, Parlaments-, Wirtschafts- oder Weltlogik.
