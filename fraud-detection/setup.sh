#!/usr/bin/env bash
set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
DB_NAME="FraudDetection"

# ── Wait for ArcadeDB ─────────────────────────────────────────────────────────
echo "Waiting for ArcadeDB at ${ARCADEDB_URL}..."
until curl -sf -u "${ARCADEDB_USER}:${ARCADEDB_PASS}" \
    "${ARCADEDB_URL}/api/v1/ready" > /dev/null 2>&1; do
  sleep 2
done
echo "ArcadeDB is ready."

# ── Create database ───────────────────────────────────────────────────────────
echo "Creating database ${DB_NAME}..."
curl -sf -u "${ARCADEDB_USER}:${ARCADEDB_PASS}" \
  -X POST "${ARCADEDB_URL}/api/v1/server" \
  -H "Content-Type: application/json" \
  -d "{\"command\": \"create database ${DB_NAME}\"}" > /dev/null || true
echo "Database ready."

# ── Helper: send one SQL statement ───────────────────────────────────────────
send_sql() {
  local stmt="$1"
  jq -cn --arg cmd "$stmt" '{"language":"sql","command":$cmd}' \
    | curl -sf -u "${ARCADEDB_USER}:${ARCADEDB_PASS}" \
        -X POST "${ARCADEDB_URL}/api/v1/command/${DB_NAME}" \
        -H "Content-Type: application/json" \
        -d @- > /dev/null
}

# ── Apply a SQL file (one statement per line) ─────────────────────────────────
apply_file() {
  local file="$1"
  echo "Applying ${file}..."
  while IFS= read -r line || [[ -n "$line" ]]; do
    # skip blank lines and SQL comments
    [[ -z "${line//[[:space:]]/}" || "$line" =~ ^[[:space:]]*-- ]] && continue
    send_sql "${line%%;}"
  done < "$file"
  echo "Done: ${file}"
}

apply_file "sql/01-schema.sql"
apply_file "sql/02-data.sql"

echo ""
echo "Setup complete. ${DB_NAME} is ready."
