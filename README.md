# Nanou Club

NANOU is a 35-ton steel Bruce Roberts cutter, built 1986 in Durban. Two world
circumnavigations under Bernard — who escaped communist Poland in a ship he
built inside a mine — then twenty years in harbour. She now lies in Port de
Masnou, near Barcelona, waiting.

This is the club that gets her sailing again: members fund the boat, paid crew
maintain her, and members join voyages — a sailing leg, or a live-aboard
harbour stay — by clicking the route line on a chart. The 2003 nanou.org
itinerary already said *"click anywhere on the blue route line"*; we kept the
interaction and pointed it at the future.

- **The adventures so far:** https://nanou.org (legacy archive, 20 years of
  stories and photos — kept intact in `mwpicard/nanou`)
- **Requirements & schema:** [docs/PRD.md](docs/PRD.md) — agreed before code
- **Stack:** GitHub Pages + Supabase (Postgres/RLS, Auth, Edge Functions),
  Leaflet + OpenStreetMap + OpenSeaMap. Scaffolded from
  [`mwpicard/webapp-template`](https://github.com/mwpicard/webapp-template).

This repo doubles as a teaching example of building a dynamic web app with
Claude Code — the PRD, schema-first workflow, and build log are part of the
point.
