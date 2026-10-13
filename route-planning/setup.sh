#!/usr/bin/env bash
set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
DB_NAME="RoutePlanning"

# The Florida road network of the 9th DIMACS Implementation Challenge: the same 2,712,798 road segments with their
# length (USA-road-d, in tenths of a meter) and their travel time (USA-road-t), plus the junctions' coordinates
DIMACS="https://www.diag.uniroma1.it/challenge9/data"
DATA="data"
DISTANCES="${DATA}/USA-road-d.FLA.gr.gz"
TIMES="${DATA}/USA-road-t.FLA.gr.gz"
COORDINATES="${DATA}/USA-road-d.FLA.co.gz"
CSV="${DATA}/florida.csv"

# ── Download the road network (once) ─────────────────────────────────────────
mkdir -p "${DATA}"
download() {
  local file="$1" url="$2"
  if [[ ! -s "$file" ]]; then
    echo "Downloading ${url}..."
    curl -sfL --retry 3 -o "${file}.part" "$url"
    mv "${file}.part" "$file"
  fi
}
download "${DISTANCES}" "${DIMACS}/USA-road-d/USA-road-d.FLA.gr.gz"
download "${TIMES}" "${DIMACS}/USA-road-t/USA-road-t.FLA.gr.gz"
download "${COORDINATES}" "${DIMACS}/USA-road-d/USA-road-d.FLA.co.gz"

# ── Convert it to the CSV of the batch endpoint (once) ───────────────────────
# Vertices come first, in the order of their DIMACS id, so that with refMode=ordinal and ordinalBase=1 an edge names
# its two junctions by their DIMACS ids. Each edge carries both costs: km, and minutes (the travel time is in
# millionths of an hour: its four road classes then drive at 40, 60, 80 and 100 km/h).
if [[ ! -s "${CSV}" ]]; then
  echo "Building ${CSV}..."
  {
    echo "@type,@class,id,lat,lon"
    gzip -dc "${COORDINATES}" | awk '$1 == "v" {
        if ($2 != ++n) { print "junction ids are not in order at " $2 > "/dev/stderr"; exit 1 }
        printf "vertex,Junction,%d,%.6f,%.6f\n", $2, $4 / 1e6, $3 / 1e6 }'
    echo "---"
    echo "@type,@class,@from,@to,km,minutes"
    paste -d ' ' <(gzip -dc "${DISTANCES}" | grep '^a ') <(gzip -dc "${TIMES}" | grep '^a ') | awk '{
        if ($2 != $6 || $3 != $7) { print "the two graphs list different arcs at line " NR > "/dev/stderr"; exit 1 }
        printf "edge,ROAD,%d,%d,%.4f,%.4f\n", $2, $3, $4 / 10000, $8 * 0.00006 }'
  } > "${CSV}.part"
  mv "${CSV}.part" "${CSV}"
fi

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
  local body
  body=$(jq -cn --arg cmd "$stmt" '{"language":"sql","command":$cmd}')
  local http_code
  http_code=$(curl -s -o /dev/null -w '%{http_code}' \
    -u "${ARCADEDB_USER}:${ARCADEDB_PASS}" \
    -X POST "${ARCADEDB_URL}/api/v1/command/${DB_NAME}" \
    -H "Content-Type: application/json" \
    -d "$body")
  if [[ "$http_code" -ge 400 ]]; then
    echo "  FAILED (HTTP $http_code): $stmt" >&2
    return 1
  fi
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

# ── Load the road network with GraphBatch, over HTTP ─────────────────────────
echo "Loading ${CSV} through the batch endpoint..."
curl -sf -u "${ARCADEDB_USER}:${ARCADEDB_PASS}" \
  -X POST "${ARCADEDB_URL}/api/v1/batch/${DB_NAME}?refMode=ordinal&ordinalBase=1&expectedVertexCount=1070376&expectedEdgeCount=2712798" \
  -H "Content-Type: text/csv" \
  --data-binary "@${CSV}" | jq -c '{verticesCreated, edgesCreated, elapsedMs}'

apply_file "sql/02-places.sql"
apply_file "sql/03-view.sql"

# ── Wait for the contraction hierarchies ──────────────────────────────────────
# The view and its hierarchies are built in the background (a few seconds for Florida). Queries never wait for them:
# until a hierarchy is ready they are answered exactly by bidirectional Dijkstra. The demo is more telling once they
# are ready, so wait until both report READY.
cch_status() {
  jq -cn --arg c "SELECT contractionHierarchies FROM schema:graphAnalyticalViews WHERE name = 'Florida'" \
      '{"language":"sql","command":$c}' \
    | curl -sf -u "${ARCADEDB_USER}:${ARCADEDB_PASS}" -X POST "${ARCADEDB_URL}/api/v1/query/${DB_NAME}" \
        -H "Content-Type: application/json" -d @- \
    | jq -r '[.result[0].contractionHierarchies[]? | .weightProperty + "=" + .status] | join(" ")'
}

echo "Waiting for the contraction hierarchies..."
for attempt in $(seq 1 120); do
  status="$(cch_status)"
  if [[ "$status" == *"km=READY"* && "$status" == *"minutes=READY"* ]]; then
    echo "  ready: ${status}"
    break
  fi
  sleep 1
done

echo ""
echo "Setup complete. ${DB_NAME} is ready."
