#!/usr/bin/env bash
#
# Regenerates database/CURRENT-SCHEMA.sql from the live database.
#
# The snapshot is the answer to "what columns does this table actually have?".
# database/schema/*.sql is an append-only log of changes that have already been
# applied — useful for history, useless for reading a table's current shape,
# because a table like tournament_details is spread across a dozen of them in an
# order nothing records. This script regenerates the single file that does say.
#
# Run it after any schema change so the snapshot does not drift:
#
#     ./database/regenerate-schema-snapshot.sh
#
# Needs SUPABASE_DB_PASSWORD_NANOU in the environment (it is in ~/.zshrc).
#
# Structure only — no rows are read, so the output never contains customer data.
# It does contain function bodies; those are reviewed for secrets by the check at
# the end of this script.

set -euo pipefail

PGDUMP=/opt/homebrew/opt/libpq/bin/pg_dump
PROJECT_REF=qrwkqnhdcoftikeancxr
OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/CURRENT-SCHEMA.sql"

if [[ -z "${SUPABASE_DB_PASSWORD_NANOU:-}" ]]; then
    echo "SUPABASE_DB_PASSWORD_NANOU is not set. Run:  source ~/.zshrc" >&2
    exit 1
fi
if [[ ! -x "$PGDUMP" ]]; then
    echo "pg_dump not found at $PGDUMP (brew install libpq)" >&2
    exit 1
fi

CONN="postgresql://postgres.${PROJECT_REF}:${SUPABASE_DB_PASSWORD_NANOU}@aws-1-eu-west-3.pooler.supabase.com:5432/postgres"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# --schema=public only: auth/storage/realtime are Supabase's to manage.
# The \restrict and \unrestrict lines carry a token that is random per run, so
# stripping them is what makes two regenerations diffable. They matter only when
# replaying a dump into a live server; this file is a reference, not a restore
# path, so losing them costs nothing.
"$PGDUMP" "$CONN" \
    --schema-only \
    --no-owner \
    --no-privileges \
    --schema=public \
  | grep -vE '^\\(un)?restrict ' > "$TMP"

if [[ ! -s "$TMP" ]]; then
    echo "pg_dump produced nothing — snapshot left unchanged." >&2
    exit 1
fi

{
    echo "--"
    echo "-- GUIDAL — current public schema. GENERATED FILE, DO NOT EDIT."
    echo "--"
    echo "-- Regenerate with ./database/regenerate-schema-snapshot.sh after any"
    echo "-- schema change. This is the authoritative answer to what a table looks"
    echo "-- like now; database/schema/*.sql only records how it got there."
    echo "--"
    echo "-- Structure only — no table data is included."
    echo "--"
    echo ""
    cat "$TMP"
} > "$OUT"

echo "Wrote $OUT"
printf '  %s tables, %s views, %s functions, %s policies, %s indexes, %s triggers\n' \
    "$(grep -c '^CREATE TABLE'    "$OUT" || true)" \
    "$(grep -c '^CREATE VIEW'     "$OUT" || true)" \
    "$(grep -c '^CREATE FUNCTION' "$OUT" || true)" \
    "$(grep -c '^CREATE POLICY'   "$OUT" || true)" \
    "$(grep -c '^CREATE INDEX'    "$OUT" || true)" \
    "$(grep -c '^CREATE TRIGGER'  "$OUT" || true)"

# Function bodies land in this file, so fail loudly if one ever carries a real
# secret. Note this looks for key MATERIAL, not the word "service_role" — that
# appears legitimately in dozens of RLS policy names and grants.
#
# The public anon key is deliberately allowed: it is already committed in
# js/supabase-client.js and shipped to every browser, so it is not a secret.
ANON_KEY="$(grep -oE 'eyJ[A-Za-z0-9_.-]+' "$(dirname "$OUT")/../js/supabase-client.js" 2>/dev/null | head -1)"

# Any JWT in the dump that is not that anon key — e.g. a service_role key.
STRAY_JWT="$(grep -oE 'eyJ[A-Za-z0-9_.-]{40,}' "$OUT" | sort -u | grep -vxF "${ANON_KEY:-__none__}" || true)"
# Provider secrets: Stripe live/test, Resend.
PROVIDER="$(grep -nE 'sk_live_[A-Za-z0-9]|sk_test_[A-Za-z0-9]|\bre_[A-Za-z0-9]{20,}' "$OUT" || true)"

if [[ -n "$STRAY_JWT" || -n "$PROVIDER" ]]; then
    echo ""
    echo "WARNING — possible secret in a function body. Review before committing:" >&2
    [[ -n "$STRAY_JWT" ]] && echo "  unrecognised JWT(s): $STRAY_JWT" >&2
    [[ -n "$PROVIDER" ]] && echo "$PROVIDER" >&2
    exit 1
fi
echo "  no secrets detected (public anon key allowed)"
