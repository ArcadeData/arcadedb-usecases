#!/usr/bin/env bash
# Customer 360 — six query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
DB="Customer360"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "${ARCADEDB_USER}:${ARCADEDB_PASS}" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Identity Resolution — Transitive Link Discovery ==="
echo "Find all identifiers belonging to the same person as alice@example.com."
echo ""
query "sql" "
SELECT linked.identifierType AS type, linked.identifierValue AS value
FROM (
  MATCH {type: Identifier, where: (identifierValue = 'alice@example.com')}
        .out('OBSERVED_IN'){}.in('OBSERVED_IN'){}
        .out('OBSERVED_IN'){}.in('OBSERVED_IN'){}
        .out('OBSERVED_IN'){}.in('OBSERVED_IN'){as: linked}
  RETURN DISTINCT linked
)
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Fuzzy Name Matching for Deduplication ==="
echo "Find probable duplicate customers by similar names sharing the same phone."
echo ""
query "cypher" "
MATCH (a:Customer), (b:Customer)
WHERE a.phone = b.phone AND a.id < b.id
RETURN a.id AS id_a, a.name AS name_a,
       b.id AS id_b, b.name AS name_b,
       a.phone AS phone
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Complete Customer 360 View ==="
echo "Unified profile for c1: household, recent purchases, open tickets, lifetime value."
echo ""
query "cypher" "
MATCH (c:Customer {id: 'c1'})
OPTIONAL MATCH (c)-[:MEMBER_OF]->(h:Household)<-[:MEMBER_OF]-(member:Customer)
WHERE member <> c
OPTIONAL MATCH (c)-[p:PURCHASED]->(prod:Product)
OPTIONAL MATCH (c)-[:OPENED]->(t:Ticket)
WHERE t.status = 'open'
RETURN c.name AS customer,
       c.lifetimeValue AS ltv,
       collect(DISTINCT member.name) AS household_members,
       collect(DISTINCT prod.name) AS purchased_products,
       collect(DISTINCT t.subject) AS open_tickets
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Churn Risk Scoring ==="
echo "Score active customers by churned-neighbor ratio in their social network."
echo ""
query "sql" "
SELECT c.id, c.name,
       count(neighbor) AS total_neighbors,
       sum(CASE WHEN neighbor.status = 'churned' THEN 1 ELSE 0 END) AS churned_neighbors
FROM (
  MATCH {type: Customer, where: (status = 'active'), as: c}
        .bothE('REFERRED', 'CONNECTED_TO'){}
        .bothV(){as: neighbor, where: (\$currentMatch != c)}
  RETURN c, neighbor
)
GROUP BY c.id, c.name
ORDER BY churned_neighbors DESC
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: Cross-Sell via Household & Collaborative Filtering ==="
echo "Recommend products for c1 based on household and similar-customer purchases."
echo ""
query "cypher" "
MATCH (c:Customer {id: 'c1'})
OPTIONAL MATCH (c)-[:MEMBER_OF]->(:Household)<-[:MEMBER_OF]-(hm:Customer)-[:PURCHASED]->(hp:Product)
WHERE NOT (c)-[:PURCHASED]->(hp)
OPTIONAL MATCH (c)-[:PURCHASED]->(:Product)<-[:PURCHASED]-(sim:Customer)-[:PURCHASED]->(sp:Product)
WHERE NOT (c)-[:PURCHASED]->(sp)
WITH c, collect(DISTINCT hp) + collect(DISTINCT sp) AS candidates
UNWIND candidates AS rec
RETURN DISTINCT rec.name AS product,
       rec.category AS category,
       rec.price AS price
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 6: Journey Path Analysis ==="
echo "Find most common conversion paths: ad_click -> page_view -> purchase."
echo ""
query "cypher" "
MATCH (c:Customer)-[:INTERACTED]->(e1:Event {eventType: 'ad_click'})
      -[:FOLLOWED_BY]->(e2:Event {eventType: 'page_view'})
      -[:FOLLOWED_BY]->(e3:Event {eventType: 'purchase'})
RETURN e1.channel AS entry_channel,
       e2.page AS landing_page,
       count(*) AS conversions
ORDER BY conversions DESC
LIMIT 20
"
