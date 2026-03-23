# AI/ML Feature Store

Demonstrates ArcadeDB as a unified feature store for production ML systems,
replacing the typical scatter of 3+ specialized databases (graph DB, vector DB,
time-series DB) with a single multi-model engine serving three ML teams:

- **Fraud scoring** — graph topology + behavior vectors + transaction velocity
- **Product recommendations** — collaborative filtering + product embeddings
- **Predictive maintenance** — equipment dependency graph + sensor aggregates

A cross-cutting Feature Store infrastructure layer records feature snapshots
for audit and lineage, demonstrating training-serving consistency.

## Prerequisites

- Docker and Docker Compose
- `curl` and `jq`
- Java 21+ and Maven 3.x (for the Java demo)
- Node.js 22+ (for the JavaScript demo)

## Quickstart

### 1. Start ArcadeDB

```bash
docker compose up -d
```

### 2. Create database and load data

```bash
./setup.sh
```

This creates the `FeatureStore` database, applies the schema, and inserts sample data.

### 3a. Run queries via curl

```bash
./queries/queries.sh
```

### 3b. Run queries via Java

```bash
cd java
mvn package -q
java -jar target/feature-store.jar
```

### 3c. Run queries via JavaScript (PostgreSQL protocol)

```bash
cd js
npm install
node feature-store.js
```

## Schema

| Type | Kind | Key properties |
|------|------|----------------|
| `Account` | Vertex | `accountId`, `accountType`, `signupSource`, `flagged`, `behaviorVec` |
| `Merchant` | Vertex | `merchantId`, `category`, `riskTier` |
| `User` | Vertex | `userId`, `preferenceVec` |
| `Product` | Vertex | `productId`, `name`, `category`, `price`, `embedding` |
| `Equipment` | Vertex | `equipmentId`, `name`, `specifications`, `failureRate` |
| `Sensor` | Vertex | `sensorId`, `sensorType`, `unit` |
| `TRANSFERRED` | Edge | Account → Account (`amount`, `recordedAt`) |
| `LINKED_DEVICE` | Edge | Account → Account (`deviceId`) |
| `TRANSACTED` | Edge | Account → Merchant (`amount`, `recordedAt`) |
| `PURCHASED` | Edge | User → Product |
| `DEPENDS_ON` | Edge | Equipment → Equipment (`criticality`) |
| `MONITORED_BY` | Edge | Equipment → Sensor |
| `TransactionMetric` | Document | `accountId`, `txCount`, `totalAmount`, `recordedAt` |
| `SensorReading` | Document | `equipmentId`, `temperature`, `vibration`, `pressure`, `recordedAt` |
| `FeatureSnapshot` | Document | `entityId`, `entityType`, `featureVector`, `computedAt`, `modelVersion` |

## Query Patterns

| # | Pattern | Language | Signal type | Domain |
|---|---------|----------|-------------|--------|
| 1 | Account Graph Features | SQL MATCH | Graph | Fraud |
| 2 | Distance to Flagged Account | SQL MATCH | Graph | Fraud |
| 3 | Behavior Similarity Search | SQL + vectorNeighbors | Vector | Fraud |
| 4 | Transaction Velocity | SQL | Time-series | Fraud |
| 5 | Shared Device Network | Cypher | Graph | Fraud |
| 6 | Collaborative Filtering | Cypher | Graph | Recommendations |
| 7 | Product Embedding Search | SQL + vectorNeighbors | Vector | Recommendations |
| 8 | Personalized Ranking | SQL + vectorNeighbors | Vector | Recommendations |
| 9 | Equipment Dependency Chain | SQL MATCH | Graph | Maintenance |
| 10 | Sensor Anomaly Detection | SQL | Time-series | Maintenance |
| 11 | Feature Vector Assembly | SQL (multi-step) | All | Cross-domain |

## Sample Data

### Fraud Domain
- 6 accounts (a1–a3 legit, a4–a5 suspicious, a6 flagged) with 4-d behavior vectors
- 4 merchants (grocery, electronics, gambling, crypto)
- ~12 TRANSFERRED edges with circular money flow pattern (a4↔a5↔a6)
- 4 LINKED_DEVICE edges (a4, a5 share devices with flagged a6)
- 15 TransactionMetric documents across 3 time buckets

### Recommendation Domain
- 5 users with 4-d preference vectors
- 8 products across Electronics, Books, Sports with 4-d embeddings
- 14 PURCHASED edges with deliberate overlap (u1+u2 share purchases → collab signal)

### Maintenance Domain
- 5 equipment units with dependency chain (eq2, eq3, eq4 depend on eq1)
- 3 sensors monitoring equipment
- 12 SensorReading documents (eq1 showing anomalous high temperature/vibration)

### Feature Store Infrastructure
- 3 FeatureSnapshot documents for audit trail

## Connectivity

| Runner | Protocol | Port |
|--------|----------|------|
| curl / shell | HTTP API | 2480 |
| Java (`arcadedb-network`) | HTTP API | 2480 |
| JavaScript (`pg`) | PostgreSQL wire protocol | 5432 |

The JavaScript module uses the `{cypher}` prefix for Cypher queries over PostgreSQL protocol.

## ArcadeDB Version Notes

This use case targets ArcadeDB **26.3.2**. Vector similarity queries use
`vectorNeighbors('TypeName[property]', vector, k)` with an `LSM_VECTOR`
index.

## Reference

[ArcadeDB AI/ML Feature Store use case](https://arcadedb.com/ai-ml-feature-store.html)
