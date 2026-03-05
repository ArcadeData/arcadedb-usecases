# Realtime Analytics Use Case — Design

**Date:** 2026-03-05
**Branch:** feat/realtime-analytics
**ArcadeDB version:** 26.3.1

## Overview

Implement the [ArcadeDB Realtime Analytics](https://arcadedb.com/realtime-analytics.html) use case. The use case demonstrates ArcadeDB's native time-series engine combined with graph traversal, showing how a single database can replace a fragmented stack of InfluxDB + Neo4j + Grafana for unified operational analytics.

Two intertwined domains form a single "operations platform":

- **IoT / Building sensors** — SensorReading time-series, Building→Floor→Sensor graph topology
- **Service monitoring** — ServiceMetrics time-series, Server→Service dependency graph

## Repository Structure

```
realtime-analytics/
├── README.md
├── docker-compose.yml
├── setup.sh
├── sql/
│   ├── 01-schema.sql
│   ├── 02-data.sql
│   └── 03-aggregates.sql
├── queries/
│   └── queries.sh
└── java/
    ├── pom.xml
    └── src/main/java/com/arcadedb/examples/RealtimeAnalytics.java
```

## Docker Compose

- Single service: `arcadedata/arcadedb:26.3.1`
- HTTP API port exposed: `2480`
- Root password via `JAVA_OPTS: "-Darcadedb.server.rootPassword=arcadedb"`
- Healthcheck: `curl -sf http://localhost:2480/api/v1/ready`, interval 5s, retries 20

## Schema (`sql/01-schema.sql`)

### Time-Series Types

**SensorReading**
- TIMESTAMP `ts` PRECISION NANOSECOND
- TAGS: `sensor_id` STRING, `location` STRING, `floor` STRING
- FIELDS: `temperature` DOUBLE, `humidity` DOUBLE, `pressure` DOUBLE
- SHARDS 16, RETENTION 90 DAYS, COMPACTION INTERVAL 30s

**ServiceMetrics**
- TIMESTAMP `ts` PRECISION NANOSECOND
- TAGS: `service_id` STRING, `server_id` STRING
- FIELDS: `request_count` LONG, `error_count` LONG, `latency_ms` DOUBLE
- SHARDS 8, RETENTION 30 DAYS

### Graph Vertex Types

| Type | Properties |
|------|-----------|
| `Building` | `name` STRING |
| `Floor` | `name` STRING, `level` INTEGER |
| `Sensor` | `name` STRING, `sensor_id` STRING |
| `Server` | `name` STRING, `server_id` STRING |
| `Service` | `name` STRING, `service_id` STRING |

### Graph Edge Types

| Type | Direction |
|------|-----------|
| `HAS_FLOOR` | Building → Floor |
| `INSTALLED_IN` | Sensor → Floor |
| `RUNS_ON` | Service → Server |
| `DEPENDS_ON` | Service → Service |

The graph and time-series worlds connect via shared IDs (`sensor_id`, `service_id`) rather than direct edges, matching the `TIMESERIES sensor -> SensorReading AS ts` join pattern.

## Sample Data (`sql/02-data.sql`)

### Graph Topology

- 2 buildings: HQ, Data Center
- 4 floors: HQ-1, HQ-2, DC-1, DC-2
- 6 sensors: s-A through s-F (3 per building, spread across floors)
- 3 servers: srv-1, srv-2, srv-3
- 5 services: api-gateway, auth-service, user-service, payment-service, notification-service
- Service dependency chain: api-gateway → auth-service + user-service, user-service → payment-service, payment-service → notification-service
- ~15 edges wiring the topology

### Time-Series Data

- ~20 SensorReading rows across 6 sensors, spanning a 2-hour window with readings every 10-15 minutes. Temperatures: 20-25°C for HQ, 18-21°C for Data Center. Sensor s-C has a deliberate gap for the interpolation query.
- ~15 ServiceMetrics rows across 5 services, spanning the same window. api-gateway has high request counts; payment-service has a few errors for the impact analysis query.

Total: ~50-60 SQL statements.

## Continuous Aggregate (`sql/03-aggregates.sql`)

```sql
CREATE CONTINUOUS AGGREGATE hourly_sensor_temps AS
SELECT
  time_bucket('1 hour', ts) AS hour,
  sensor_id,
  avg(temperature) AS avg_temp,
  max(temperature) AS max_temp,
  min(temperature) AS min_temp
FROM SensorReading
GROUP BY hour, sensor_id
```

Applied after schema and data so the aggregate has rows to process.

## Queries

### Query 1: Hourly Temperature Bucketing (SQL)

Aggregate sensor s-A readings into 1-hour buckets with avg, max, p99 temperature, and sample count.

```sql
SELECT
  time_bucket('1h', ts) AS hour,
  sensor_id,
  avg(temperature) AS avg_temp,
  max(temperature) AS max_temp,
  percentile(temperature, 0.99) AS p99_temp,
  count(*) AS samples
FROM SensorReading
WHERE ts BETWEEN '...' AND '...'
  AND sensor_id = 's-A'
GROUP BY hour, sensor_id
ORDER BY hour
```

### Query 2: Service Request Rate & Latency (SQL)

5-minute windowed rate of change and p99 latency per service.

```sql
SELECT
  time_bucket('5m', ts) AS window,
  service_id,
  rate(request_count) AS requests_per_sec,
  percentile(latency_ms, 0.99) AS p99_latency
FROM ServiceMetrics
WHERE ts BETWEEN '...' AND '...'
GROUP BY window, service_id
```

### Query 3: Gap Filling with Interpolation (SQL)

Fill missing temperature readings for sensor s-C using linear interpolation.

```sql
SELECT
  time_bucket('1m', ts) AS minute,
  interpolate(temperature, 'linear', ts) AS temp_filled
FROM SensorReading
WHERE sensor_id = 's-C'
  AND ts BETWEEN '...' AND '...'
GROUP BY minute
```

### Query 4: Graph + Time-Series Correlation (SQL)

Traverse the Building→Floor→Sensor topology from HQ, then join each sensor to its SensorReading data.

```sql
SELECT
  sensor.name,
  avg(ts.temperature) AS avg_temp,
  max(ts.temperature) AS max_temp,
  count(*) AS samples
FROM (
  TRAVERSE out('HAS_FLOOR').out('INSTALLED_IN')
  FROM (SELECT FROM Building WHERE name = 'HQ')
  WHILE $depth <= 2
) AS sensor
WHERE sensor.@type = 'Sensor'
  AND ts.ts BETWEEN '...' AND '...'
TIMESERIES sensor -> SensorReading AS ts
GROUP BY sensor.name
```

### Query 5: Service Impact Analysis (Cypher)

Given a failing server, traverse RUNS_ON and DEPENDS_ON edges to find affected services with live metrics.

```cypher
MATCH (failing:Server {server_id: 'srv-1'})
  <-[:RUNS_ON]-(svc:Service)
RETURN svc.name,
  ts.rate(svc, 'ServiceMetrics', 'request_count',
    now() - duration('PT10M'), now()) AS current_rps,
  ts.last(svc, 'ServiceMetrics', 'error_count') AS errors
```

### Query 6: Continuous Aggregate (SQL)

Query the pre-computed hourly rollup.

```sql
SELECT * FROM hourly_sensor_temps
WHERE hour BETWEEN '...' AND '...'
ORDER BY hour, sensor_id
```

## Query Language Mapping

| # | Pattern | Language | Signal type |
|---|---------|----------|-------------|
| 1 | Hourly Temperature Bucketing | SQL | Time-series |
| 2 | Service Request Rate & Latency | SQL | Time-series |
| 3 | Gap Filling with Interpolation | SQL | Time-series |
| 4 | Graph + Time-Series Correlation | SQL | Graph + Time-series |
| 5 | Service Impact Analysis | Cypher | Graph + Time-series |
| 6 | Continuous Aggregate Query | SQL | Time-series (materialized) |

## Java Program (`java/`)

- **Build tool:** Maven (standalone `pom.xml`, no parent)
- **Dependency:** `com.arcadedb:arcadedb-network:26.3.1`
- **Output:** executable fat JAR via `maven-assembly-plugin` (`mvn package` → `java -jar target/realtime-analytics.jar`)
- **Entry point:** single `RealtimeAnalytics.java` with a `main` method that:
  1. Opens a `RemoteDatabase` connection to `localhost:2480`
  2. Runs all 6 queries sequentially via `tryRun()` wrapper
  3. Prints a header and formatted results for each query to stdout
  4. Closes the connection

## CI Workflow

`.github/workflows/realtime-analytics.yml` with the standard matrix pattern:

```yaml
matrix:
  runner: [curl, java]
```

Each matrix entry:
1. Checks out code
2. Sets up Java 21 (temurin) — gated on `matrix.runner == 'java'`
3. Caches `~/.m2` — gated on `matrix.runner == 'java'`
4. `docker compose up -d`
5. `./setup.sh`
6. Runs curl queries OR builds/runs Java fat JAR
7. `docker compose down` with `if: always()`

## Success Criteria

- `docker compose up` starts ArcadeDB successfully
- SQL files (schema, data, aggregates) apply cleanly via `curl` with no errors
- `queries.sh` runs all 6 queries and returns non-empty result sets
- `mvn package && java -jar ...` runs all 6 queries and prints results to stdout
