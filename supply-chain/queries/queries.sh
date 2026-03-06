#!/usr/bin/env bash
# Supply Chain Management — all five query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="SupplyChain"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Multi-Tier Supplier Discovery ==="
echo "Find all suppliers (up to 4 tiers) feeding into Widget Pro X."
echo ""
query "cypher" "
MATCH (p:Product {sku: 'WIDGET-PRO-X'})
      <-[:CONTAINS]-(c:Component)
      <-[:SUPPLIES*1..4]-(s:Supplier)
RETURN DISTINCT s.name, s.country, s.risk_score
ORDER BY s.risk_score DESC
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Blast Radius Analysis ==="
echo "If Shenzhen Micro Ltd is disrupted, which products are affected?"
echo ""
query "cypher" "
MATCH (s:Supplier {name: 'Shenzhen Micro Ltd'})
      -[:SUPPLIES]->(c:Component)
      -[:CONTAINS]->(p:Product)
OPTIONAL MATCH (c)<-[:ALTERNATIVE_FOR]-(alt:Supplier)
RETURN c.name AS component, p.name AS product,
       p.revenue_annual AS revenue_at_risk, collect(alt.name) AS alternatives
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Delivery Disruption Detection ==="
echo "Identify suppliers with delivery issues from DeliveryMetric records."
echo ""
query "sql" "
SELECT supplierId,
       avg(lead_time_hrs) AS avg_lead_time,
       sum(CASE WHEN delayed = true THEN 1 ELSE 0 END) AS total_delayed,
       count(*) AS total_deliveries
FROM DeliveryMetric
GROUP BY supplierId
ORDER BY total_delayed DESC
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Vector-Based Alternative Sourcing ==="
echo "Find suppliers with capabilities similar to Shenzhen Micro Ltd [0.9, 0.2, 0.1, 0.1]."
echo ""
query "sql" "
SELECT name, country, risk_score
FROM Supplier
WHERE status = 'active'
ORDER BY vectorNeighbors('Supplier[capability_vec]', [0.9, 0.2, 0.1, 0.1], 10) DESC
LIMIT 5
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: End-to-End Batch Traceability ==="
echo "Trace all raw materials in batch BATCH-2026-0218 through the assembly chain."
echo ""
query "cypher" "
MATCH (p:Product {batchId: 'BATCH-2026-0218'})
      <-[:ASSEMBLED_FROM*1..8]-(material)
RETURN material.name, material.origin, material.certification, material.lot
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 6: Inventory Intelligence ==="
echo "Identify products in warehouses with low stock (< 5 weeks)."
echo ""
query "sql" "
SELECT warehouse, stock_weeks, product, revenue_annual
FROM (
  MATCH {type: Warehouse, where: (stock_weeks < 5)}{as: w}
        .in('STORED_AT'){as: p}
  RETURN w.name AS warehouse, w.stock_weeks AS stock_weeks,
         p.name AS product, p.revenue_annual AS revenue_annual
)
ORDER BY stock_weeks ASC
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 7: Recall Simulation ==="
echo "Trace downstream from raw material lot LOT-2026-001 to affected products and customers."
echo ""
query "cypher" "
MATCH (rm:RawMaterial {lot: 'LOT-2026-001'})
      -[:ASSEMBLED_FROM*1..4]->(p:Product)
      -[:SHIPPED_TO]->(c:Customer)
RETURN rm.name AS material, p.name AS product,
       p.sku AS sku, c.customerId AS customer
"
