#!/usr/bin/env bash
# Realtime Analytics — all six query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="RealtimeAnalytics"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# Epoch ms constants for 2026-02-20
# 10:00 = 1771581600000, 12:00 = 1771588800000

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Hourly Temperature Bucketing ==="
echo "Aggregate sensor s-A readings into 1-hour buckets."
echo ""
query "sql" "
SELECT
  ts.timeBucket('1h', ts) AS hour,
  sensor_id,
  avg(temperature) AS avg_temp,
  max(temperature) AS max_temp,
  ts.percentile(temperature, 0.99) AS p99_temp,
  count(*) AS samples
FROM SensorReading
WHERE ts BETWEEN 1771581600000 AND 1771588800000
  AND sensor_id = 's-A'
GROUP BY hour, sensor_id
ORDER BY hour
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Service Request Rate & Latency ==="
echo "10-minute windowed rate and p99 latency per service."
echo ""
query "sql" "
SELECT
  ts.timeBucket('10m', ts) AS window,
  service_id,
  ts.rate(request_count, ts) AS requests_per_sec,
  ts.percentile(latency_ms, 0.99) AS p99_latency
FROM ServiceMetrics
WHERE ts BETWEEN 1771581600000 AND 1771588800000
GROUP BY window, service_id
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Gap Filling with Interpolation ==="
echo "Fill missing temperature readings for sensor s-C using linear interpolation."
echo ""
query "sql" "
SELECT
  ts.timeBucket('1m', ts) AS minute,
  ts.interpolate(temperature, 'linear', ts) AS temp_filled
FROM SensorReading
WHERE sensor_id = 's-C'
  AND ts BETWEEN 1771581600000 AND 1771587000000
GROUP BY minute
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Graph + Time-Series Correlation ==="
echo "Step 1: Traverse HQ building topology to find sensors."
echo ""
query "sql" "
SELECT sensor.sensor_id AS sensor_id, sensor.name AS sensor_name
FROM (
  MATCH {type: Building, where: (name = 'HQ')}
        .out('HAS_FLOOR'){as: floor}
        .in('INSTALLED_IN'){as: sensor}
  RETURN sensor
)
"

echo ""
echo "Step 2: Aggregate time-series data for HQ sensors."
echo ""
query "sql" "
SELECT
  sensor_id,
  avg(temperature) AS avg_temp,
  max(temperature) AS max_temp,
  count(*) AS samples
FROM SensorReading
WHERE sensor_id IN ['s-A', 's-B', 's-C']
  AND ts BETWEEN 1771581600000 AND 1771588800000
GROUP BY sensor_id
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: Service Impact Analysis ==="
echo "Step 1: Find services affected by srv-1 failure (Cypher graph traversal)."
echo ""
query "cypher" "
MATCH (failing:Server {server_id: 'srv-1'})
  <-[:RUNS_ON]-(directSvc:Service)
  -[:DEPENDS_ON*0..3]->(depSvc:Service)
RETURN DISTINCT depSvc.name AS service_name, depSvc.service_id AS service_id
"

echo ""
echo "Step 2: Get latest metrics for affected services."
echo ""
query "sql" "
SELECT
  service_id,
  ts.rate(request_count, ts) AS requests_per_sec,
  sum(error_count) AS total_errors,
  ts.percentile(latency_ms, 0.99) AS p99_latency
FROM ServiceMetrics
WHERE ts BETWEEN 1771581600000 AND 1771588800000
GROUP BY service_id
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 6: Continuous Aggregate ==="
echo "Query pre-computed hourly temperature rollup."
echo ""
query "sql" "
SELECT *
FROM hourly_sensor_temps
WHERE hour BETWEEN 1771581600000 AND 1771588800000
ORDER BY hour, sensor_id
"
