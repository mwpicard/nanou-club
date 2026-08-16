# Project Instructions

<!-- FILL IN: one paragraph on what this app is and who uses it. -->

- Production URL: https://EXAMPLE.org (GitHub Pages, deploys from `main`)
- Supabase project ref: `FILL_ME`
- DB password env var: `SUPABASE_DB_PASSWORD_FILL_ME` (in ~/.zshrc)

## Git Workflow

**NEVER push without asking first.** Committing locally is fine, but pushes to
`main` go live immediately. Work in small, verified slices.

## Feature Protection

Before every commit, review `features.md` for features touching the files you
modified and verify the *behavior* is preserved, not just the code structure.
Add new features to `features.md` as they land.

## Database Rules

- Read `database/CURRENT-SCHEMA.sql` before writing or modifying ANY query.
  Never assume table or column names.
- Schema changes go in `supabase/migrations/`, then run
  `./database/regenerate-schema-snapshot.sh` to refresh the snapshot.
- Every table has RLS enabled and policies written the moment it is created.

## Supabase Edge Functions

```bash
/opt/homebrew/bin/supabase functions deploy <name>
/opt/homebrew/bin/supabase functions logs <name>
```
Deploy automatically after creating or modifying a function in `supabase/functions/`.

## Verification

Serve locally with `python3 -m http.server 8080` and drive the browser
(Playwright MCP / Chrome extension) to verify each feature before committing.
