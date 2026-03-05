# Realtime Analytics

Demonstrates ArcadeDB's native time-series engine combined with graph traversal,
showing how a single database replaces a fragmented stack of specialized tools
for unified operational analytics.

- **Time-series analytics** — time bucketing, rate of change, percentiles, interpolation
- **Graph traversal** — building topology and service dependency analysis
- **Multi-model correlation** — graph traversal + time-series aggregation in two-step patterns

## Prerequisites

- Docker and Docker Compose
- `curl` and `jq`
- Java 21+ and Maven 3.x (for the Java demo)

## Quickstart

### 1. Start ArcadeDB

```bash
docker compose up -d
```

### 2. Create database and load data

```bash
./setup.sh
```

This creates the `RealtimeAnalytics` database, applies the schema, inserts
sample data, and creates continuous aggregates.

### 3a. Run queries via curl

```bash
./queries/queries.sh
```

### 3b. Run queries via Java

```bash
cd java
mvn package -q
java -jar target/realtime-analytics.jar
```

## Schema

### Time-Series Types

| Type | Tags | Fields |
|------|------|--------|
| `SensorReading` | `sensor_id`, `location` | `temperature`, `humidity`, `pressure` |
| `ServiceMetrics` | `service_id`, `server_id` | `request_count`, `error_count`, `latency_ms` |

### Graph Types

| Type | Kind | Key properties |
|------|------|----------------|
| `Building` | Vertex | `name` |
| `Floor` | Vertex | `name`, `level` |
| `Sensor` | Vertex | `name`, `sensor_id` |
| `Server` | Vertex | `name`, `server_id` |
| `Service` | Vertex | `name`, `service_id` |
| `HAS_FLOOR` | Edge | Building -> Floor |
| `INSTALLED_IN` | Edge | Sensor -> Floor |
| `RUNS_ON` | Edge | Service -> Server |
| `DEPENDS_ON` | Edge | Service -> Service |

## Query Patterns

| # | Pattern | Language | Signal type |
|---|---------|----------|-------------|
| 1 | Hourly Temperature Bucketing | SQL | Time-series |
| 2 | Service Request Rate & Latency | SQL | Time-series |
| 3 | Gap Filling with Interpolation | SQL | Time-series |
| 4 | Graph + Time-Series Correlation | SQL | Graph + Time-series |
| 5 | Service Impact Analysis | Cypher | Graph + Time-series |
| 6 | Continuous Aggregate Query | SQL | Time-series (materialized) |

## Sample Data

- 2 buildings (HQ, Data Center) with 4 floors
- 6 sensors across both buildings
- 3 servers and 5 services with dependency chain
- ~20 sensor readings over a 2-hour window (sensor s-C has a deliberate gap)
- ~15 service metrics with varying load and error rates

## ArcadeDB Version Notes

This use case targets ArcadeDB **26.3.1**. Time-series queries use native
`ts.timeBucket()`, `ts.rate()`, `ts.percentile()`, and `ts.interpolate()` functions.
Graph and time-series data are correlated using a two-step query pattern: a graph
traversal to identify entities, followed by a time-series query filtered to those entities.

## Reference

[ArcadeDB Realtime Analytics use case](https://arcadedb.com/realtime-analytics.html)
