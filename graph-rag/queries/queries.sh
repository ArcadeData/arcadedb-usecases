#!/usr/bin/env bash
# Graph RAG — all five query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="GraphRAG"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Hybrid Vector + Graph (SQL+Cypher hybrid) ==="
echo "Find chunks similar to a query embedding and include entity mentions."
echo ""
query "sql" "
SELECT content, source,
       out('MENTIONS').name AS entities
FROM Chunk
ORDER BY vectorNeighbors('Chunk[embedding]', [0.9, 0.2, 0.1, 0.1], 5) DESC
LIMIT 5
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Multi-Hop Entity Bridge (Cypher) ==="
echo "Find chunks connected through shared entities."
echo ""
query "cypher" "
MATCH (direct:Chunk)-[:MENTIONS]->(entity)<-[:MENTIONS]-(related:Chunk)
WHERE direct.source = 'Getting Started with GraphRAG'
  AND related.source <> direct.source
RETURN direct.source AS source_doc,
       entity.name AS bridge_entity,
       related.content AS connected_content,
       related.source AS connected_doc
LIMIT 20
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Temporal-Aware Retrieval (Cypher) ==="
echo "Get latest chunks per source."
echo ""
query "cypher" "
MATCH (c:Chunk)
WHERE c.chunkIndex = 1
RETURN c.content, c.source, c.chunkIndex
ORDER BY c.chunkIndex DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Composite Scoring: Vector + Entity Count (SQL) ==="
echo "Score chunks by vector distance and entity connections."
echo ""
query "sql" "
SELECT content, source,
       out('MENTIONS').size() AS entity_count
FROM Chunk
ORDER BY vectorNeighbors('Chunk[embedding]', [0.9, 0.2, 0.1, 0.1], 10) DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: Agentic RAG Steps ==="
echo "Simulate agent steps: vector search, graph expansion, full-text lookup, authorship."
echo ""

echo "--- Step 1: Vector search for relevant chunks ---"
query "sql" "
SELECT content, source
FROM Chunk
ORDER BY vectorNeighbors('Chunk[embedding]', [0.9, 0.2, 0.1, 0.1], 5) DESC
LIMIT 5
"

echo ""
echo "--- Step 2: Graph expansion — entities and relations ---"
query "cypher" "
MATCH (c:Chunk {source: 'Getting Started with GraphRAG'})-[:MENTIONS]->(e)-[:RELATES_TO]->(related)
RETURN e.name, related.name
LIMIT 10
"

echo ""
echo "--- Step 3: Full-text lookup ---"
query "sql" "
SELECT content, source
FROM Chunk
WHERE content CONTAINSTEXT 'knowledge graph'
LIMIT 5
"

echo ""
echo "--- Step 4: Authorship ---"
query "cypher" "
MATCH (p:Person)-[:AUTHORED]->(c:Chunk)
RETURN p.name, c.source, c.chunkIndex
LIMIT 10
"
