#!/usr/bin/env bash
# Knowledge Graph — all five query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="KnowledgeGraph"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Co-authorship Network (Graph Traversal) ==="
echo "Find researchers reachable from Alice (r1) within 2 co-authorship hops."
echo ""
query "cypher" "
MATCH (me:Researcher {id: 'r1'})
      -[:CO_AUTHORED]->(p:Paper)
      <-[:CO_AUTHORED]-(colleague:Researcher)
      -[:CO_AUTHORED]->(collab:Paper)
WHERE colleague.id <> 'r1'
  AND NOT (me)-[:CO_AUTHORED]->(collab)
RETURN colleague.name, collab.title, count(DISTINCT p) AS shared_papers
ORDER BY shared_papers DESC LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Semantic Paper Search (Vector Similarity) ==="
echo "Find papers semantically similar to the embedding [0.8, 0.2, 0.1, 0.1]."
echo ""
query "sql" "
SELECT id, title, year
FROM Paper
ORDER BY vectorNeighbors('Paper[embedding]', [0.8, 0.2, 0.1, 0.1], 10) DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Full-Text Search Meets Graph Context ==="
echo "Find papers matching 'distributed AND consensus', then expand to co-authors."
echo ""

echo "--- Step 1: Full-text search ---"
query "sql" "
SELECT id, title, year
FROM Paper
WHERE SEARCH_INDEX('Paper[abstract]', 'distributed AND consensus') = true
LIMIT 10
"

echo ""
echo "--- Step 2: Graph expansion — co-authors of matching papers ---"
echo "Note: paper IDs are hardcoded from Step 1 results since SEARCH_INDEX"
echo "is not supported inside a MATCH where clause."
query "sql" "
SELECT paper, author
FROM (
  MATCH {type: Paper, as: p, where: (id IN ['p1', 'p9'])}
        .in('CO_AUTHORED'){as: a}
  RETURN p.title AS paper, a.name AS author
)
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Trending Papers (Time-Series) ==="
echo "Rank papers by cumulative citation activity."
echo ""
query "sql" "
SELECT paperId, sum(citationCount) AS totalCitations
FROM PaperActivity
GROUP BY paperId
ORDER BY totalCitations DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: GraphRAG Hybrid (Vector Seed + Citation Expansion) ==="
echo "Find topics reachable via citation graph from papers most similar to [0.8, 0.2, 0.1, 0.1]."
echo "Note: paper IDs are hardcoded because ArcadeDB does not support a SELECT subquery"
echo "inside a MATCH 'where' clause; these IDs are the top-3 vector-similarity results."
echo ""
query "sql" "
SELECT topic.name AS topic, count(*) AS connections
FROM (
  MATCH {type: Paper, where: (id IN ['p2', 'p8', 'p4'])}
        .out('CITES'){as: cited}
        .out('COVERS'){as: topic}
  RETURN topic
)
GROUP BY topic
ORDER BY connections DESC
LIMIT 5
"
