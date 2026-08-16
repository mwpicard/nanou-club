# webapp-template

Martin's standard starting point for a dynamic web app built with Claude Code.

**Stack:** static HTML/CSS/JS frontend on GitHub Pages (custom domain via CNAME)
+ Supabase (Postgres with RLS, Auth, Edge Functions) as the dynamic layer.
Maps use Leaflet.js + OpenStreetMap.

## Using this template

```bash
gh repo create <org>/<name> --template mwpicard/webapp-template --public --clone
```

Then:
1. Fill in the placeholders in `CLAUDE.md` (domain, Supabase project ref, what the app is).
2. Write the PRD in `docs/PRD.md` and agree the schema **before** writing app code.
3. Create the Supabase project, `supabase link`, write migrations in `supabase/migrations/`.
4. Set `PROJECT_REF` in `database/regenerate-schema-snapshot.sh` and run it after every schema change.
5. Build one feature at a time; keep `features.md` current; verify in a real browser before committing.
6. Enable GitHub Pages, add `CNAME`, confirm the smoke workflow goes green.

## Rules that travel with every project

- Never push without asking — pushes to `main` go live.
- Verify DB schema (`database/CURRENT-SCHEMA.sql`) before writing queries.
- RLS on every table from the first migration. Anon key in the browser is fine; service-role keys never are.
- AI/API keys live only in Edge Functions.
