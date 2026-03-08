# Customer 360 — Design Document

**Date:** 2026-03-07
**Branch:** `feat/customer`
**Database:** `Customer360`
**ArcadeDB Version:** 26.3.1
**Connectivity:** HTTP API (`arcadedb-network`)

## Overview

A unified customer view use case demonstrating all five ArcadeDB multi-model pillars — graph, documents, time-series, vectors, and full-text search — through identity resolution, churn prediction, cross-sell recommendations, and journey analytics.

**Key differentiator:** Uses OpenCypher as the primary query language, demonstrating polyglot SQL + Cypher across all six queries. Based on the scenario at https://arcadedb.com/customer-360.html.

## Directory Structure

```
customer-360/
├── docker-compose.yml          # ArcadeDB 26.3.1 (port 2480)
├── setup.sh                    # Creates DB, applies SQL schema + data via HTTP API
├── sql/
│   ├── 01-schema.sql           # 10 vertex types, 11 edge types, vector + full-text indexes
│   └── 02-data.sql             # ~95 INSERT + CREATE EDGE statements
├── queries/
│   └── queries.sh              # 6 query sections via curl (HTTP API), SQL + Cypher
├── java/
│   ├── pom.xml                 # arcadedb-network 26.3.1, fat JAR
│   └── src/main/java/com/arcadedb/examples/Customer360.java
└── README.md
```

## Docker Compose

- Image: `arcadedata/arcadedb:26.3.1`
- Ports: `2480:2480` (HTTP)
- Root password: `JAVA_OPTS: "-Darcadedb.server.rootPassword=arcadedb"`
- Healthcheck: `wget --spider -q http://localhost:2480/api/v1/ready`, interval 5s, retries 20

## Schema

### Vertex Types (10)

| Type | Properties | Notes |
|------|-----------|-------|
| `Customer` | id STRING, name STRING, email STRING, phone STRING, status STRING, prefVector FLOAT[], recentBehavior FLOAT[], baselineBehavior FLOAT[], lifetimeValue DOUBLE | status: active/churned |
| `Household` | id STRING, name STRING | Groups related customers |
| `Product` | id STRING, name STRING, category STRING, price DOUBLE, embedding FLOAT[] | For cross-sell |
| `Device` | id STRING, deviceType STRING, os STRING | Customer touchpoints |
| `Address` | id STRING, street STRING, city STRING, state STRING, zip STRING | Customer locations |
| `Ticket` | id STRING, subject STRING, status STRING, content STRING, createdAt STRING | Support interactions |
| `Campaign` | id STRING, name STRING, channel STRING | Marketing initiatives |
| `Session` | id STRING, startedAt STRING | Interaction sessions for identity resolution |
| `Event` | id STRING, eventType STRING, channel STRING, page STRING, recordedAt STRING | ad_click, page_view, purchase |
| `Identifier` | id STRING, identifierType STRING, identifierValue STRING | email, phone, cookie, deviceId, loyaltyNumber |

### Edge Types (11)

| Edge | From -> To | Properties |
|------|-----------|-----------|
| `PURCHASED` | Customer -> Product | purchasedAt STRING |
| `LIVES_AT` | Customer -> Address | |
| `USED` | Customer -> Device | |
| `MEMBER_OF` | Customer -> Household | |
| `OPENED` | Customer -> Ticket | |
| `CLICKED` | Customer -> Campaign | |
| `REFERRED` | Customer -> Customer | |
| `CONNECTED_TO` | Customer -> Customer | |
| `OBSERVED_IN` | Identifier -> Session | |
| `INTERACTED` | Customer -> Event | |
| `FOLLOWED_BY` | Event -> Event | |

### Indexes

- `LSM_VECTOR` on `Customer[prefVector]` (8 dimensions, COSINE)
- `LSM_VECTOR` on `Product[embedding]` (8 dimensions, COSINE)
- Full-text index on `Ticket[content]`

## Sample Data

Small but sufficient to make every query return meaningful results. Deliberate overlap is critical.

### Customers (6)

- c1: Alice Smith (active), c2: Bob Smith (active), c3: Carol Johnson (active), c4: Dave Johnson (churned), c5: Alicia Smith (active, fuzzy-dedup pair with c1), c6: Frank Wilson (churned)
- c1 & c2 in Household h1; c3 & c4 in Household h2
- c4 & c6 churned — neighbors of active customers for churn risk signal
- Each has prefVector, recentBehavior, baselineBehavior (8D floats)
- c3 has drifted behavior (recentBehavior diverges from baseline -> high churn signal)

### Households (2)

- h1: "Smith Family" (Alice + Bob)
- h2: "Johnson Family" (Carol + Dave)

### Products (6)

Mix of Electronics and Outdoor categories, each with 8D embedding.

### Identifiers & Sessions (identity resolution)

- 6 identifiers for c1: email, phone, cookie, loyaltyNumber, second cookie, deviceId
- 3 sessions where identifiers co-occur (cookie seen in same session as email -> transitive link)

### Events (journey path analysis)

- 3 complete conversion paths: ad_click -> page_view -> purchase (linked by FOLLOWED_BY)
- Different channels (google, facebook) and pages (landing-a, landing-b)

### Tickets (3)

- One open, two closed — with text content for full-text search

### Social Graph (churn risk)

- REFERRED: c1 -> c4 (churned), c2 -> c3
- CONNECTED_TO: c3 -> c6 (churned), c5 -> c4 (churned)

### Purchases (collaborative filtering + cross-sell)

- c1 and c2 share some purchases (household members)
- c3 and c5 share purchases (collaborative filtering signal)
- Some products only purchased by household members (cross-sell candidates)

### Estimated Total

~95 SQL statements in `02-data.sql`.

## Query Patterns

### queries.sh (HTTP API, curl)

Six labeled sections using the standard `query()` helper.

### Java (HTTP API, RemoteDatabase)

Six queries using `tryRun()`/`printHeader()` pattern.

| # | Name | Language | Pillars | Description |
|---|------|----------|---------|-------------|
| 1 | Identity Resolution | SQL MATCH | Graph | 3-hop transitive link discovery via OBSERVED_IN through sessions |
| 2 | Fuzzy Deduplication | Cypher | Document | Cross-match customers with shared phone number |
| 3 | Full Customer 360 View | Cypher | Graph | OPTIONAL MATCH across household, recent purchases, open tickets; lifetime value aggregation |
| 4 | Churn Risk Scoring | SQL MATCH | Graph | Social network traversal, churned-neighbor ratio, composite risk |
| 5 | Cross-Sell Recommendations | Cypher | Graph | Household purchases + collaborative filtering |
| 6 | Journey Path Analysis | Cypher | Graph | Event chains via FOLLOWED_BY, conversion path frequency and grouping |

### Query Adaptations from Website

- Q1: Cypher variable-length paths `*1..3` don't work in ArcadeDB — use SQL MATCH with explicit 3-hop chain
- Q2: SQL Cartesian product `FROM a, b` not supported — use Cypher cross-match `MATCH (a), (b)`
- `ts.last()`, `ts.rate()`: Not available — use direct property reads
- `vectorDistance()`: Not available in 26.3.1 — use `vectorNeighbors()` if needed
- `similarity()`: Not available — use deterministic phone matching instead
- Q3 Java: `arcadedb-network` client fails deserializing Cypher `collect()` results with single elements (ClassCastException: String -> Object[]) — Java version splits Q3 into separate sub-queries

## Java Program

### Class: `com.arcadedb.examples.Customer360`

### Connection

```java
RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD);
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ARCADEDB_HOST` | `localhost` | ArcadeDB host |
| `ARCADEDB_PORT` | `2480` | HTTP port |
| `ARCADEDB_USER` | `root` | Username |
| `ARCADEDB_PASS` | `arcadedb` | Password |

### Query Execution

- SQL: `db.query("sql", "...")`
- OpenCypher: `db.query("cypher", "...")`
- Results via `ResultSet` iteration

### pom.xml

```xml
<dependency>
    <groupId>com.arcadedb</groupId>
    <artifactId>arcadedb-network</artifactId>
    <version>26.3.1</version>
</dependency>
```

Fat JAR via `maven-assembly-plugin` with `appendAssemblyId=false`.
Main class: `com.arcadedb.examples.Customer360`.
Maven compiler target: Java 21.

## CI Workflow

**File:** `.github/workflows/customer-360.yml`

Same matrix pattern as all other use cases:

```yaml
matrix:
  runner: [curl, java]
```

- Triggers on push/PR to `customer-360/**`
- Steps: checkout -> setup Java 21 (conditional) -> Maven cache -> docker compose up -> setup.sh -> queries/build+run -> docker compose down
- Maven cache key: `customer-360`
- JAR filename: `customer-360.jar`
- curl runner uses HTTP API
- java runner uses HTTP API via arcadedb-network

## Success Criteria

1. `docker compose up -d` starts ArcadeDB on port 2480
2. `setup.sh` creates the database and applies schema + data without errors
3. `queries.sh` returns results for all 6 queries via HTTP API
4. Java program connects via HTTP, runs all 6 queries (SQL + OpenCypher), and prints results
5. CI matrix passes for both `curl` and `java` runners
