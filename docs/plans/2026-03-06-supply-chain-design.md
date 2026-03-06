# Supply Chain Management Use Case — Design

**Date:** 2026-03-06
**Branch:** feat/supply-chain
**ArcadeDB version:** 26.3.1

## Overview

Implement the [ArcadeDB Supply Chain Management](https://arcadedb.com/supply-chain.html) use case. The scenario demonstrates ArcadeDB's ability to model supply chains as interconnected graphs with multi-tier supplier discovery, blast radius analysis, vector-based alternative sourcing, time-series delivery tracking, and end-to-end traceability — all in a single database.

This use case adds a **JavaScript runner** (via ArcadeDB's PostgreSQL wire protocol and the `pg` driver) alongside the established shell and Java runners.

## Repository Structure

```
supply-chain/
├── README.md
├── docker-compose.yml
├── setup.sh
├── sql/
│   ├── 01-schema.sql
│   └── 02-data.sql
├── queries/
│   └── queries.sh
├── java/
│   ├── pom.xml
│   └── src/main/java/com/arcadedb/examples/SupplyChain.java
└── js/
    ├── package.json
    └── supply-chain.js
```

## Docker Compose

- Single service: `arcadedata/arcadedb:26.3.1`
- Ports exposed: `2480` (HTTP API), `5432` (PostgreSQL protocol)
- Root password via `JAVA_OPTS: "-Darcadedb.server.rootPassword=arcadedb"`
- PostgreSQL plugin enabled via `JAVA_OPTS` flag: `-Darcadedb.server.plugins=Postgres:com.arcadedb.postgres.PostgresProtocolPlugin`
- Healthcheck: `curl -sf http://localhost:2480/api/v1/ready`

## Schema (`sql/01-schema.sql`)

Seven vertex types, seven edge types, and one document type.

### Vertices

| Type | Properties | Notes |
|------|-----------|-------|
| `Supplier` | `name` (STRING), `country` (STRING), `risk_score` (FLOAT), `lead_time_avg` (INTEGER), `quality_score` (FLOAT), `certifications` (STRING), `status` (STRING), `capability_vec` (LIST) | Vector index on `capability_vec` (LSM_VECTOR, 4D, COSINE) |
| `Component` | `name` (STRING) | Intermediate nodes in supply chain |
| `Product` | `sku` (STRING), `name` (STRING), `revenue_annual` (FLOAT), `batchId` (STRING) | Unique index on `sku` |
| `Warehouse` | `name` (STRING), `stock_weeks` (INTEGER) | Inventory locations |
| `Customer` | `customerId` (STRING), `contact_email` (STRING) | End customers |
| `ShippingRoute` | `name` (STRING), `transit_days` (INTEGER), `cost` (FLOAT) | Logistics paths |
| `RawMaterial` | `name` (STRING), `origin` (STRING), `certification` (STRING), `lot` (STRING) | Raw inputs for traceability |

### Edges

| Type | Direction | Purpose |
|------|-----------|---------|
| `SUPPLIES` | Supplier → Supplier, Supplier → Component | Multi-tier supply chain (variable-length traversal) |
| `CONTAINS` | Component → Product | Bill of materials |
| `STORED_AT` | Product → Warehouse | Inventory location |
| `SHIPS_VIA` | Warehouse → ShippingRoute | Logistics routing |
| `SHIPPED_TO` | Product → Customer | Order fulfillment |
| `ALTERNATIVE_FOR` | Supplier → Component | Alternative sourcing options |
| `ASSEMBLED_FROM` | RawMaterial → Component, Component → Product | Physical traceability chain (variable-length traversal) |

### Document

| Type | Properties | Purpose |
|------|-----------|---------|
| `DeliveryMetric` | `supplierId` (STRING), `lead_time_hrs` (FLOAT), `on_time` (BOOLEAN), `delayed` (BOOLEAN), `quantity` (INTEGER), `recordedAt` (DATETIME) | Time-series delivery performance |

## Sample Data (`sql/02-data.sql`)

### Suppliers (7, with multi-tier relationships)

| Name | Country | Risk | Tier | Capability Vector |
|------|---------|------|------|-------------------|
| Shenzhen Micro Ltd | China | 0.7 | 1 | [0.9, 0.2, 0.1, 0.1] |
| Taiwan Semi Corp | Taiwan | 0.3 | 2 | [0.8, 0.1, 0.3, 0.1] |
| Seoul Chip Inc | South Korea | 0.4 | 2 | [0.85, 0.15, 0.1, 0.1] |
| Berlin Sensors GmbH | Germany | 0.2 | 1 | [0.2, 0.9, 0.1, 0.1] |
| Sao Paulo Materials | Brazil | 0.5 | 3 | [0.1, 0.1, 0.9, 0.1] |
| Tokyo Electronics | Japan | 0.15 | 1 | [0.85, 0.3, 0.1, 0.1] |
| Mumbai Parts Ltd | India | 0.45 | 1 | [0.7, 0.1, 0.3, 0.2] |

### Supply Chain Tiers

```
Sao Paulo Materials (tier 3) -[SUPPLIES]-> Taiwan Semi Corp (tier 2)
Taiwan Semi Corp (tier 2) -[SUPPLIES]-> Shenzhen Micro Ltd (tier 1)
Seoul Chip Inc (tier 2) -[SUPPLIES]-> Shenzhen Micro Ltd (tier 1)
Shenzhen Micro Ltd (tier 1) -[SUPPLIES]-> Microcontroller
Berlin Sensors GmbH (tier 1) -[SUPPLIES]-> Sensor Module
Mumbai Parts Ltd (tier 1) -[SUPPLIES]-> Circuit Board
Tokyo Electronics (tier 1) -[SUPPLIES]-> Display Panel
```

### Alternative Sourcing

```
Tokyo Electronics -[ALTERNATIVE_FOR]-> Microcontroller
Seoul Chip Inc -[ALTERNATIVE_FOR]-> Circuit Board
```

### Components (5)

Microcontroller, Sensor Module, Circuit Board, Display Panel, Battery Pack

### Products (3)

| SKU | Name | Revenue | Batch |
|-----|------|---------|-------|
| WIDGET-PRO-X | Widget Pro X | 2,500,000 | BATCH-2026-0218 |
| WIDGET-LITE | Widget Lite | 800,000 | BATCH-2026-0301 |
| SENSOR-HUB-1 | Sensor Hub | 1,200,000 | BATCH-2026-0115 |

### Bill of Materials (CONTAINS edges)

- Widget Pro X: Microcontroller, Sensor Module, Circuit Board
- Widget Lite: Display Panel, Battery Pack
- Sensor Hub: Sensor Module, Microcontroller

### Traceability (ASSEMBLED_FROM edges)

```
Silicon Wafer -[ASSEMBLED_FROM]-> Microcontroller -[ASSEMBLED_FROM]-> Widget Pro X
Copper Wire -[ASSEMBLED_FROM]-> Circuit Board -[ASSEMBLED_FROM]-> Widget Pro X
Rare Earth Elements -[ASSEMBLED_FROM]-> Sensor Module -[ASSEMBLED_FROM]-> Widget Pro X
Glass Substrate -[ASSEMBLED_FROM]-> Display Panel -[ASSEMBLED_FROM]-> Widget Lite
Lithium -[ASSEMBLED_FROM]-> Battery Pack -[ASSEMBLED_FROM]-> Widget Lite
Sensor Module -[ASSEMBLED_FROM]-> Sensor Hub
Microcontroller -[ASSEMBLED_FROM]-> Sensor Hub
```

### Warehouses (3), ShippingRoutes (3), Customers (3)

Standard logistics data linking products → warehouses → shipping routes, and products → customers.

### DeliveryMetric Documents (~15 records)

Multiple delivery records per supplier with varied `lead_time_hrs`, `on_time`/`delayed` flags, and `quantity` values. Uses `recordedAt` (not `timestamp` — reserved word).

## Query Patterns

Five queries demonstrating different ArcadeDB capabilities:

| # | Pattern | Shell/Java Language | JS Language | Signal type |
|---|---------|--------------------|----|-------------|
| 1 | Multi-tier supplier discovery | Cypher | SQL MATCH | Graph (variable-length path) |
| 2 | Blast radius analysis | Cypher | SQL MATCH | Graph (OPTIONAL MATCH / subquery) |
| 3 | Delivery disruption detection | SQL | SQL | Time-series aggregation |
| 4 | Vector-based alternative sourcing | SQL | SQL | Vector similarity |
| 5 | End-to-end batch traceability | Cypher | SQL MATCH | Graph (variable-length path) |

### Query Details

**Query 1 — Multi-tier supplier discovery (Cypher)**
Find all suppliers (up to 4 tiers deep) that feed into Widget Pro X.
```cypher
MATCH (p:Product {sku: 'WIDGET-PRO-X'})
      <-[:CONTAINS]-(c:Component)
      <-[:SUPPLIES*1..4]-(s:Supplier)
RETURN DISTINCT s.name, s.country, s.risk_score
ORDER BY s.risk_score DESC
```

**Query 2 — Blast radius analysis (Cypher)**
If Shenzhen Micro Ltd is disrupted, which products are affected and what alternatives exist?
```cypher
MATCH (s:Supplier {name: 'Shenzhen Micro Ltd'})
      -[:SUPPLIES]->(c:Component)
      -[:CONTAINS]->(p:Product)
OPTIONAL MATCH (c)<-[:ALTERNATIVE_FOR]-(alt:Supplier)
RETURN c.name AS component, p.name AS product, collect(alt.name) AS alternatives
```

If OPTIONAL MATCH is not supported, fall back to two separate queries.

**Query 3 — Delivery disruption detection (SQL)**
Identify suppliers with delivery issues by aggregating DeliveryMetric documents.
```sql
SELECT supplierId,
       avg(lead_time_hrs) AS avg_lead_time,
       sum(CASE WHEN delayed = true THEN 1 ELSE 0 END) AS total_delayed,
       count(*) AS total_deliveries
FROM DeliveryMetric
GROUP BY supplierId
ORDER BY total_delayed DESC
```

**Query 4 — Vector-based alternative sourcing (SQL)**
Find suppliers with capabilities similar to Shenzhen Micro Ltd's capability vector [0.9, 0.2, 0.1, 0.1].
```sql
SELECT name, country, risk_score
FROM Supplier
WHERE status = 'active'
ORDER BY vectorNeighbors('Supplier[capability_vec]', [0.9, 0.2, 0.1, 0.1], 10) DESC
LIMIT 5
```

**Query 5 — End-to-end batch traceability (Cypher)**
Trace all raw materials used in batch BATCH-2026-0218 through the assembly chain.
```cypher
MATCH (p:Product {batchId: 'BATCH-2026-0218'})
      <-[:ASSEMBLED_FROM*1..8]-(material)
RETURN material.name, material.origin, material.certification, material.lot
```

## JavaScript Runner (`js/`)

- **Runtime:** Node.js (CommonJS)
- **Dependency:** `pg` (node-postgres)
- **Protocol:** ArcadeDB PostgreSQL wire protocol on port 5432
- **Connection:** `postgresql://root:arcadedb@localhost:5432/SupplyChain`
- **Queries:** All 5 patterns rewritten as ArcadeDB SQL (including MATCH syntax for graph traversals), since the PostgreSQL protocol only accepts SQL
- **Entry point:** `node js/supply-chain.js` — runs all 5 queries sequentially, prints formatted results to stdout

## Java Runner (`java/`)

- **Dependency:** `com.arcadedb:arcadedb-network:26.3.1`
- **Entry point:** `java -jar target/supply-chain.jar`
- **Pattern:** Same `tryRun()`/`printHeader()` pattern as recommendation-engine
- **Queries:** Mix of SQL and Cypher (same as shell queries)

## CI Workflow

Matrix with 3 runners: `[curl, java, js]`

| Runner | Setup | Run command |
|--------|-------|-------------|
| `curl` | (none) | `./queries/queries.sh` |
| `java` | `setup-java@v5` (temurin 21), cache `~/.m2` | `mvn package && java -jar target/supply-chain.jar` |
| `js` | `setup-node@v4`, `npm install` in `js/`, cache `~/.npm` | `node js/supply-chain.js` |

## Success Criteria

- `docker compose up` starts ArcadeDB with HTTP + PostgreSQL ports accessible
- SQL files apply cleanly via `setup.sh`
- `queries.sh` runs all 5 queries and returns non-empty result sets
- Java program runs all 5 queries and prints results
- JavaScript program connects via PostgreSQL protocol, runs all 5 queries, and prints results
- CI workflow passes for all 3 matrix runners
