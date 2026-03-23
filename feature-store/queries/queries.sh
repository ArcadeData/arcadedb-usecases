#!/usr/bin/env bash
# AI/ML Feature Store — all 11 query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="FeatureStore"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"
COMMAND_URL="${ARCADEDB_URL}/api/v1/command/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

send_command() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$COMMAND_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "========== FRAUD DOMAIN =========="
echo ""
echo "=== Query 1: Account Graph Features (SQL MATCH) ==="
echo "Compute graph topology features for account a4."
echo ""
query "sql" "
SELECT inDeg, outDeg, counterparties
FROM (
  MATCH {type: Account, where: (accountId = 'a4'), as: acct}
  RETURN acct.in('TRANSFERRED').size() AS inDeg,
         acct.out('TRANSFERRED').size() AS outDeg,
         acct.both('TRANSFERRED').size() AS counterparties
)
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Distance to Flagged Account (SQL MATCH) ==="
echo "Find shortest path from a4 to nearest flagged account via transfers."
echo ""
query "sql" "
SELECT accountId AS flaggedId, depth
FROM (
  MATCH {type: Account, where: (accountId = 'a4')}
        .both('TRANSFERRED'){while: (\$depth < 4), as: hop}
  RETURN hop.accountId AS accountId, hop.flagged AS flagged, \$depth AS depth
)
WHERE flagged = true
ORDER BY depth ASC
LIMIT 1
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Behavior Similarity Search (SQL) ==="
echo "Find accounts with behavior vectors similar to flagged a6 [0.9,0.8,0.1,0.2]."
echo ""
query "sql" "
SELECT accountId, accountType, flagged
FROM Account
ORDER BY vectorNeighbors('Account[behaviorVec]', [0.9, 0.8, 0.1, 0.2], 10) DESC
LIMIT 5
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Transaction Velocity (SQL) ==="
echo "Aggregate TransactionMetric for velocity features per account."
echo ""
query "sql" "
SELECT accountId,
       sum(txCount) AS totalTx,
       sum(totalAmount) AS totalAmount,
       avg(totalAmount) AS avgBucketAmount
FROM TransactionMetric
GROUP BY accountId
ORDER BY totalTx DESC
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: Shared Device Network (Cypher) ==="
echo "Find accounts sharing devices with flagged accounts."
echo ""
query "cypher" "
MATCH (flagged:Account {flagged: true})
      -[:LINKED_DEVICE]-(suspect:Account)
WHERE suspect.flagged = false
RETURN DISTINCT suspect.accountId, suspect.accountType,
       flagged.accountId AS linkedToFlagged
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "========== RECOMMENDATION DOMAIN =========="
echo ""
echo "=== Query 6: Collaborative Filtering (Cypher) ==="
echo "Find products to recommend to u1 based on shared purchases."
echo ""
query "cypher" "
MATCH (me:User {userId: 'u1'})
      -[:PURCHASED]->(p:Product)
      <-[:PURCHASED]-(other:User)
      -[:PURCHASED]->(rec:Product)
WHERE rec <> p
  AND NOT (me)-[:PURCHASED]->(rec)
RETURN rec.name, rec.category, count(DISTINCT other) AS score
ORDER BY score DESC LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 7: Product Embedding Search (SQL) ==="
echo "Find products similar to Laptop embedding [0.9,0.1,0.1,0.1]."
echo ""
query "sql" "
SELECT name, category, price
FROM Product
ORDER BY vectorNeighbors('Product[embedding]', [0.9, 0.1, 0.1, 0.1], 10) DESC
LIMIT 5
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 8: Category Vector Search (SQL) ==="
echo "Rank Electronics products by similarity to u1 preference [0.9,0.1,0.1,0.1]."
echo ""
query "sql" "
SELECT name, price
FROM Product
WHERE category = 'Electronics'
ORDER BY vectorNeighbors('Product[embedding]', [0.9, 0.1, 0.1, 0.1], 20) DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "========== MAINTENANCE DOMAIN =========="
echo ""
echo "=== Query 9: Equipment Dependency Chain (SQL MATCH) ==="
echo "Find all downstream equipment affected if eq1 fails."
echo ""
query "sql" "
SELECT name, failureRate, criticality, depth
FROM (
  MATCH {type: Equipment, where: (equipmentId = 'eq1')}
        .inE('DEPENDS_ON'){while: (\$depth < 5), as: e}
        .outV(){as: dep}
  RETURN dep.name AS name, dep.failureRate AS failureRate,
         e.criticality AS criticality, \$depth AS depth
)
ORDER BY depth ASC
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 10: Sensor Anomaly Detection (SQL) ==="
echo "Find equipment with anomalous sensor readings."
echo ""
query "sql" "
SELECT equipmentId,
       avg(temperature) AS avgTemp,
       max(vibration) AS maxVibration,
       avg(pressure) AS avgPressure
FROM SensorReading
GROUP BY equipmentId
ORDER BY avgTemp DESC
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "========== CROSS-DOMAIN =========="
echo ""
echo "=== Query 11: Feature Vector Assembly (Multi-step) ==="
echo "Assemble a fraud feature vector for account a4."
echo ""

echo "--- Step 1: Graph features (degree + counterparties) ---"
query "sql" "
SELECT inDeg, outDeg, counterparties
FROM (
  MATCH {type: Account, where: (accountId = 'a4'), as: acct}
  RETURN acct.in('TRANSFERRED').size() AS inDeg,
         acct.out('TRANSFERRED').size() AS outDeg,
         acct.both('TRANSFERRED').size() AS counterparties
)
"

echo ""
echo "--- Step 2: Vector features (similarity rank to known fraud) ---"
query "sql" "
SELECT accountId, flagged
FROM Account
ORDER BY vectorNeighbors('Account[behaviorVec]', [0.7, 0.6, 0.2, 0.3], 10) DESC
LIMIT 5
"

echo ""
echo "--- Step 3: Time-series features (transaction velocity) ---"
query "sql" "
SELECT sum(txCount) AS totalTx,
       sum(totalAmount) AS totalAmount,
       avg(totalAmount) AS avgBucketAmount
FROM TransactionMetric
WHERE accountId = 'a4'
"

echo ""
echo "--- Step 4: Store feature snapshot ---"
send_command "sql" "
INSERT INTO FeatureSnapshot SET entityId = 'a4', entityType = 'Account',
  featureVector = [8, 6, 3, 67, 145000, 0.87],
  computedAt = '2026-03-23 00:00:00', modelVersion = 'fraud-v2.2'
"
echo "(Snapshot stored)"

echo ""
echo "--- Verify: Feature snapshots for a4 ---"
query "sql" "
SELECT entityId, modelVersion, computedAt
FROM FeatureSnapshot
WHERE entityId = 'a4'
ORDER BY computedAt DESC
"
