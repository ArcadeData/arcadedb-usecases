#!/usr/bin/env bash
# Recommendation Engine — all five query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
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
SELECT name, category, price
FROM Product
WHERE inStock = true
ORDER BY vectorNeighbors('Product[embedding]', [0.9, 0.1, 0.1, 0.1], 20) DESC
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
echo "=== Query 4: Graph Traversal — Streaming Platform ==="
echo "Recommend shows to u1 based on what users with shared watch history also watched."
echo ""
query "sql" "
SELECT title, genre, count(*) AS collab_score
FROM (
  MATCH {type: User, where: (id = 'u1')}
        .out('WATCHED'){as: show}
        .in('WATCHED'){as: viewer, where: (id != 'u1')}
        .out('WATCHED'){as: rec, where: (\$matched.show != @this)}
  RETURN rec.title AS title, rec.genre AS genre
)
GROUP BY title, genre
ORDER BY collab_score DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: E-Commerce Personalized Category Page ==="
echo "Rank Electronics products for u1 by vector relevance to their preference embedding."
echo ""
query "sql" "
SELECT name, category, price
FROM Product
WHERE category = 'Electronics'
  AND inStock = true
ORDER BY vectorNeighbors('Product[embedding]', [0.9, 0.1, 0.1, 0.1], 30) DESC
LIMIT 30
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 6: Hybrid Multi-Model Recommendation ==="
echo "Combine graph (collaborative filtering), vector (user preference similarity),"
echo "and time-series (trending scores) for u1."
echo ""

echo "--- Step 1: Graph — collaborative filtering candidates ---"
query "cypher" "
MATCH (me:User {id: 'u1'})
      -[:PURCHASED]->(p:Product)
      <-[:PURCHASED]-(other:User)
      -[:PURCHASED]->(rec:Product)
WHERE rec <> p
  AND NOT (me)-[:PURCHASED]->(rec)
RETURN DISTINCT rec.name AS name
"

echo ""
echo "--- Step 2: Vector — rank candidates by similarity to u1 preference [0.9, 0.1, 0.1, 0.1] ---"
echo "Note: candidate names are hardcoded from Step 1 results."
query "sql" "
SELECT name, category, price
FROM Product
WHERE name IN ['Running Shoes', 'Water Bottle', 'Yoga Mat', 'Tennis Racket']
ORDER BY vectorNeighbors('Product[embedding]', [0.9, 0.1, 0.1, 0.1], 10) DESC
"

echo ""
echo "--- Step 3: Time-series — trending boost from recent interactions ---"
query "sql" "
SELECT productId, sum(purchaseCount) AS trending_score
FROM ProductInteraction
WHERE productId IN ['Running Shoes', 'Water Bottle', 'Yoga Mat', 'Tennis Racket']
GROUP BY productId
ORDER BY trending_score DESC
"
