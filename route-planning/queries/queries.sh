#!/usr/bin/env bash
# Route Planning — Tallahassee to Coral Gables on the Florida road network via curl: fewest hops, Dijkstra, A*,
# Customizable Contraction Hierarchies (CCH), shortest against fastest, live traffic
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="RoutePlanning"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"
COMMAND_URL="${ARCADEDB_URL}/api/v1/command/${DB}"

# prints the result, then how long the request took
query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" -w '\n%{time_total}\n' \
        -H "Content-Type: application/json" -d @- \
    | { read -r body; read -r seconds; echo "$body" | jq -c '.result'; awk -v s="$seconds" 'BEGIN { printf "  (%.1f ms)\n", s * 1000 }'; }
}

command() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$COMMAND_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq -c '.result'
}

FROM_TO="LET \$from = (SELECT FROM Junction WHERE name = 'Tallahassee'), \$to = (SELECT FROM Junction WHERE name = 'Coral Gables')"

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Fewest Hops ==="
echo "Tallahassee to Coral Gables with the fewest road segments, ignoring how long they are."
echo ""
query "sql" "SELECT shortestPath(\$from, \$to, 'OUT', 'ROAD').size() - 1 AS roads ${FROM_TO}"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Dijkstra ==="
echo "The fastest route, by travel time: the number of junctions on it."
echo ""
query "sql" "SELECT dijkstra(\$from, \$to, 'minutes', { direction: 'OUT', edgeTypeNames: ['ROAD'] }).size() AS junctions ${FROM_TO}"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: A* ==="
echo "The same route, guided by the coordinates (57 minutes per degree is the most that never overshoots a road)."
echo ""
query "sql" "SELECT astar(\$from, \$to, 'minutes', { direction: 'OUT', edgeTypeNames: ['ROAD'], vertexAxisNames: ['lat', 'lon'], heuristicFormula: 'EUCLIDEAN', dFactor: 57, tieBreaker: false }).size() AS junctions ${FROM_TO}"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Contraction Hierarchy ==="
echo "The same route answered by the CCH kept on the 'Florida' view: in SQL, then in Cypher with its travel time."
echo ""
query "sql" "SELECT cchShortestPath(\$from, \$to, 'minutes', { direction: 'OUT', edgeTypeNames: ['ROAD'] }).size() AS junctions ${FROM_TO}"
query "cypher" "
MATCH (a:Junction {name: 'Tallahassee'}), (b:Junction {name: 'Coral Gables'})
CALL algo.cch.shortestPath(a, b, 'ROAD', 'minutes', 'OUT') YIELD path, weight
RETURN weight AS minutes, size(path.nodes) AS junctions
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: Shortest vs Fastest ==="
echo "The route that minimizes km, and the one that minimizes minutes, each with its other cost."
echo ""
query "cypher" "
MATCH (a:Junction {name: 'Tallahassee'}), (b:Junction {name: 'Coral Gables'})
CALL algo.cch.shortestPath(a, b, 'ROAD', 'km', 'OUT') YIELD path, weight
RETURN 'shortest' AS route, weight AS km, reduce(m = 0.0, r IN path.relationships | m + r.minutes) AS minutes
"
query "cypher" "
MATCH (a:Junction {name: 'Tallahassee'}), (b:Junction {name: 'Coral Gables'})
CALL algo.cch.shortestPath(a, b, 'ROAD', 'minutes', 'OUT') YIELD path, weight
RETURN 'fastest' AS route, weight AS minutes, reduce(k = 0.0, r IN path.relationships | k + r.km) AS km
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 6: Live Traffic ==="
echo "Four hours of queue on the Turnpike south of Orlando, then the fastest route again."
echo ""
FASTEST="
MATCH (a:Junction {name: 'Tallahassee'}), (b:Junction {name: 'Coral Gables'})
CALL algo.cch.shortestPath(a, b, 'ROAD', 'minutes', 'OUT') YIELD path, weight
RETURN weight AS minutes, reduce(k = 0.0, r IN path.relationships | k + r.km) AS km
"
JAM="MATCH (:Junction {id: 702459})-[r:ROAD]->(:Junction {id: 702911}) SET r.minutes = %s RETURN r.minutes AS minutes"
echo "SET r.minutes = 240 (the Turnpike segment from junction 702459 to 702911):"
command "cypher" "$(printf "$JAM" 240)"
query "cypher" "$FASTEST"
echo "Traffic clears (minutes back to 6.3009):"
command "cypher" "$(printf "$JAM" 6.3009)"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 7: Which Engine Answered ==="
echo "Each hierarchy counts the queries it answered and the ones it handed to bidirectional Dijkstra."
echo ""
jq -cn --arg c "SELECT contractionHierarchies FROM schema:graphAnalyticalViews WHERE name = 'Florida'" '{"language":"sql","command":$c}' \
  | curl -sf -u "$AUTH" -X POST "$QUERY_URL" -H "Content-Type: application/json" -d @- \
  | jq -c '[.result[0].contractionHierarchies[] | {weightProperty, status, arcs, queries, fallbacks, lastIncrementalUpdateMicros}]'
