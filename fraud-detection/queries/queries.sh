#!/usr/bin/env bash
# Fraud Detection — all nine query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="FraudDetection"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# Faceted search (ArcadeDB 26.12.1+): the response carries "facets" next to "result"
facet_query() {
  local cmd="$1"
  jq -cn --arg c "$cmd" '{"language":"sql","command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '{result, facets}'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Fraud Ring Detection (Graph Traversal) ==="
echo "Find accounts connected to a flagged account through shared identifiers."
echo ""
query "cypher" "
MATCH (flagged:Account {id: 'acct-A'})
      -[:USES_DEVICE|HAS_PHONE|HAS_ADDRESS*1..4]-
      (connected:Account)
WHERE connected <> flagged
RETURN DISTINCT connected.id, connected.name
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Synthetic Identity Resolution ==="
echo "Find accounts sharing the same SSN (indicating synthetic identity fraud)."
echo ""
query "sql" "
SELECT id, full_name, ssn
FROM Account
WHERE ssn = '123-45-6789'
ORDER BY id
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Circular Money Flow (Graph Cycles) ==="
echo "Detect the A->B->C->D->E->A circular transfer path."
echo ""
query "cypher" "
MATCH (origin:Account {id: 'acct-A'})
      -[:TRANSFERRED_TO]->(b:Account)
      -[:TRANSFERRED_TO]->(c:Account)
      -[:TRANSFERRED_TO]->(d:Account)
      -[:TRANSFERRED_TO]->(e:Account)
      -[:TRANSFERRED_TO]->(origin)
RETURN origin.id AS origin, b.id AS hop1, c.id AS hop2, d.id AS hop3, e.id AS hop4
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Structuring Detection (Time-Series) ==="
echo "Flag accounts making 3+ deposits in the \$8,000–\$9,999 range."
echo ""
query "sql" "
SELECT FROM (
  SELECT account_id, count(*) AS deposit_count
  FROM Deposit
  WHERE amount BETWEEN 8000 AND 9999
  GROUP BY account_id
) WHERE deposit_count >= 3
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: Behavioral Anomaly (Vector Similarity) ==="
echo "Detect acct-H transactions deviating from customer profile via cosine similarity."
echo ""
query "sql" "
SELECT id, amount, merchant, account_id,
       vectorCosineSimilarity(behavior_embedding, [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]) AS profile_similarity
FROM Transaction
WHERE account_id = 'acct-H'
ORDER BY profile_similarity
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 6: Velocity Attack Detection (Time-Series) ==="
echo "Detect accounts with abnormally high transaction rates in a 5-minute window."
echo ""
query "sql" "
SELECT FROM (
  SELECT account_id, count(*) AS txn_count, min(ts) AS first_txn, max(ts) AS last_txn
  FROM Transaction
  WHERE ts BETWEEN '2026-03-01T13:00:00Z' AND '2026-03-01T13:05:00Z'
  GROUP BY account_id
) WHERE txn_count > 5
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 7: Correlated Account Activity (Time-Series) ==="
echo "Compare transfer patterns between two accounts to detect coordination."
echo ""
query "sql" "
SELECT account_id, avg(amount) AS avg_amount, count(*) AS txn_count
FROM Transaction
WHERE account_id IN ['acct-A', 'acct-B']
  AND ts >= '2026-02-01T00:00:00Z'
GROUP BY account_id
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 8: Cross-Type Investigation (SQL Subquery) ==="
echo "Find accounts linked to customers flagged as suspicious or anomalous."
echo ""
query "sql" "
SELECT id, name
FROM Account
WHERE id IN (SELECT id FROM Customer WHERE recent_behavior IN ['suspicious', 'anomalous'])
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 9: Investigation Triage (Facets) ==="
echo "Transactions of 400 or more, with merchant, account, amount band and per-day counts for the analyst."
echo ""
facet_query "
SELECT id, account_id, amount, merchant, ts
FROM Transaction
WHERE amount >= 400
FACETS
  merchant TERMS TOP 10,
  account_id TERMS,
  amountBand: amount RANGES ([*, 1000) AS 'under 1k', [1000, 8000) AS '1k-8k', [8000, 10000) AS '8k-10k (near CTR threshold)', [10000, *) AS '10k+'),
  perDay: ts HISTOGRAM CALENDAR '1d' TIMEZONE 'UTC'
LIMIT 5
"

echo ""
echo "--- Drill-down: merchant 'Transfer' selected (disjunctive facets) ---"
echo "Rows are the transfers; the merchant facet still counts every merchant so the analyst can switch."
facet_query "
SELECT id, account_id, amount, merchant
FROM Transaction
FACETS
  merchant TERMS TOP 5 FILTER merchant = 'Transfer',
  account_id TERMS
LIMIT 10
"
