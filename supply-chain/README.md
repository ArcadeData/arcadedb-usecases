# Supply Chain Management

Demonstrates ArcadeDB's multi-model capabilities by implementing a supply chain
management system that unifies three signal types in a single database:

- **Graph traversal** — multi-tier supplier discovery, blast radius analysis, end-to-end traceability
- **Vector similarity** — alternative supplier sourcing using capability embeddings
- **Time-series** — delivery disruption detection via metric aggregation

## Prerequisites

- Docker and Docker Compose
- `curl` and `jq`
- Java 21+ and Maven 3.x (for the Java demo)
- Node.js 18+ (for the JavaScript demo)

## Quickstart

### 1. Start ArcadeDB

```bash
docker compose up -d
```

### 2. Create database and load data

```bash
./setup.sh
```

This creates the `SupplyChain` database, applies the schema, and inserts sample data.

### 3a. Run queries via curl

```bash
./queries/queries.sh
```

### 3b. Run queries via Java

```bash
cd java
mvn package -q
java -jar target/supply-chain.jar
```

### 3c. Run queries via JavaScript (PostgreSQL protocol)

```bash
cd js
npm install
node supply-chain.js
```

## Schema

| Type | Kind | Key properties |
|------|------|----------------|
| `Supplier` | Vertex | `name`, `country`, `risk_score`, `lead_time_avg`, `quality_score`, `certifications`, `status`, `capability_vec` |
| `Component` | Vertex | `name` |
| `Product` | Vertex | `sku`, `name`, `revenue_annual`, `batchId` |
| `Warehouse` | Vertex | `name`, `stock_weeks` |
| `Customer` | Vertex | `customerId`, `contact_email` |
| `ShippingRoute` | Vertex | `name`, `transit_days`, `cost` |
| `RawMaterial` | Vertex | `name`, `origin`, `certification`, `lot` |
| `SUPPLIES` | Edge | Supplier → Supplier / Component (multi-tier) |
| `CONTAINS` | Edge | Component → Product (bill of materials) |
| `STORED_AT` | Edge | Product → Warehouse |
| `SHIPS_VIA` | Edge | Warehouse → ShippingRoute |
| `SHIPPED_TO` | Edge | Product → Customer |
| `ALTERNATIVE_FOR` | Edge | Supplier → Component |
| `ASSEMBLED_FROM` | Edge | RawMaterial → Component → Product (traceability) |
| `DeliveryMetric` | Document | `supplierId`, `lead_time_hrs`, `on_time`, `delayed`, `quantity`, `recordedAt` |

## Query Patterns

| # | Pattern | Language | Signal type |
|---|---------|----------|-------------|
| 1 | Multi-Tier Supplier Discovery | Cypher | Graph (variable-length path) |
| 2 | Blast Radius Analysis | Cypher | Graph (OPTIONAL MATCH) |
| 3 | Delivery Disruption Detection | SQL | Time-series aggregation |
| 4 | Vector-Based Alternative Sourcing | SQL + vectorNeighbors | Vector |
| 5 | End-to-End Batch Traceability | Cypher | Graph (variable-length path) |

The JavaScript runner uses ArcadeDB SQL (including MATCH syntax) for all queries,
since the PostgreSQL wire protocol only accepts SQL.

## Sample Data

- 7 suppliers across 3 tiers with 4-dimensional capability vectors
- 5 components, 3 products, 3 warehouses, 3 shipping routes, 3 customers
- 5 raw materials with origin and certification data
- ~50 edges creating realistic supply chain topology
- 15 delivery metric records with varied lead times and delay flags

## ArcadeDB Version Notes

This use case targets ArcadeDB **26.3.1**. Vector similarity queries use
`vectorNeighbors('Supplier[capability_vec]', vector, k)` with an `LSM_VECTOR`
index. The PostgreSQL protocol is enabled via the `Postgres:com.arcadedb.postgres.PostgresProtocolPlugin`
server plugin on port 5432.

## Reference

[ArcadeDB Supply Chain Management use case](https://arcadedb.com/supply-chain.html)
