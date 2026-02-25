#!/usr/bin/env bash
# Recommendation Engine — all five query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
AUTH="root:arcadedb"
DB="RecommendationEngine"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Collaborative Filtering (Graph Traversal) ==="
echo "Find products to recommend to u1 based on shared purchases with other users."
echo ""
query "cypher" "
MATCH (me:User {id: 'u1'})
      -[:PURCHASED]->(p:Product)
      <-[:PURCHASED]-(other:User)
      -[:PURCHASED]->(rec:Product)
WHERE rec <> p
  AND NOT (me)-[:PURCHASED]->(rec)
RETURN rec.name, rec.category, count(DISTINCT other) AS score
ORDER BY score DESC LIMIT 20
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Vector Similarity Search ==="
echo "Find products semantically similar to the Laptop embedding [0.9,0.1,0.1,0.1]."
echo ""
query "sql" "
SELECT name, category, price,
       vectorNeighbors('embedding', [0.9, 0.1, 0.1, 0.1], 20) AS similarity
FROM Product
WHERE inStock = true
ORDER BY similarity DESC
LIMIT 20
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Trending Products (Time-Series) ==="
echo "Rank products by total recent purchase interactions."
echo ""
query "sql" "
SELECT productId, sum(purchaseCount) AS totalInteractions
FROM ProductInteraction
GROUP BY productId
ORDER BY totalInteractions DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Multi-Model Hybrid — Streaming Platform ==="
echo "Recommend shows to u1 blending collaborative signal + vector similarity."
echo ""
query "sql" "
LET \$collab = (
  SELECT rec, count(DISTINCT viewer) AS collab_score
  FROM (
    MATCH {type: User, where: (id = 'u1')}
          .out('WATCHED'){as: show}
          .in('WATCHED'){as: viewer, where: (id \!= 'u1')}
          .out('WATCHED'){as: rec, where: (\$matched.show \!= @this)}
    RETURN rec, viewer
  ) GROUP BY rec
)
SELECT rec.title, rec.genre,
  collab_score,
  vectorNeighbors('embedding', [0.9, 0.1, 0.1, 0.1], 10) AS similarity,
  (0.6 * collab_score + 0.4 * similarity) AS final_score
FROM \$collab
ORDER BY final_score DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: E-Commerce Personalized Category Page ==="
echo "Rank Electronics products for u1 by vector relevance + trending interactions."
echo ""
query "cypher" "
MATCH (p:Product)
WHERE p.category = 'Electronics'
  AND p.inStock = true
RETURN p.name, p.price,
  vectorNeighbors('embedding', [0.9, 0.1, 0.1, 0.1], 30) AS relevance
ORDER BY relevance DESC
LIMIT 30
"
