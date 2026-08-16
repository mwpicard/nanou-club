# Project Instructions — Nanou Club

Membership site for the club recommissioning NANOU, a 35-ton steel Bruce
Roberts cutter (two circumnavigations, twenty years in harbour, now lying in
Port de Masnou near Barcelona). Members fund the boat, paid crew maintain her,
and members join voyages — sailing legs or live-aboard harbour stays — by
clicking the route line or harbours on an interactive chart.

- Production URL: https://mwpicard.github.io/nanou-club/ for now.
  **nanou.org will point here later** — it currently serves the legacy archive
  (repo `mwpicard/nanou`), which moves to stories.nanou.org first. Do not touch
  any CNAME/DNS without Martin's explicit go-ahead.
- Supabase project ref: `qrwkqnhdcoftikeancxr` (org Can Picard, Paris)
- DB password env var: `SUPABASE_DB_PASSWORD_NANOU` (in ~/.zshrc)
- Full requirements: `docs/PRD.md` — schema was agreed there before any code.

## Domain decisions already made (don't relitigate)

- Berths: 2 doubles, 4 singles, 1 couch (defaults on every segment). Hot
  bunking is normal — admin can confirm past capacity via `bookings.overbook`.
- Fees are decided by club vote; `fee_schedule.amount_cents` stays null until
  voted. The site's job is cost transparency, never invented prices.
- Approval bootstrap: admin approves members directly until 2 active members
  exist; then the two-member approval trigger carries the rule.
- The legacy archive repo is content, not code — link to it, never merge it.

## Git Workflow

**NEVER push without asking first.** Committing locally is fine. Pushes to
`main` deploy via GitHub Pages.

## Feature Protection

Before every commit, review `features.md` for features touching the files you
modified and verify the *behavior* survived, not just the code structure.

## Database Rules

- Read `database/CURRENT-SCHEMA.sql` before writing or modifying ANY query.
  Never assume table or column names.
- Schema changes go in `supabase/migrations/`, applied with
  `supabase db push -p "$SUPABASE_DB_PASSWORD_NANOU"`, then run
  `./database/regenerate-schema-snapshot.sh`.
- Every new table gets RLS and policies in the same migration.
- Approval quorum and berth capacity are enforced by database triggers —
  never re-implement them in JavaScript, and never bypass them.

## Supabase Edge Functions

```bash
/opt/homebrew/bin/supabase functions deploy <name>
/opt/homebrew/bin/supabase functions logs <name>
```
Deploy automatically after creating or modifying a function. Any future
secret-holding logic (Stripe, email) lives here, never in the browser.

## Verification

Serve locally with `python3 -m http.server 8090` from the repo root and drive
the browser (Playwright MCP / Chrome extension) to verify each feature before
committing. Use relative URLs everywhere — the site serves from a subpath.
