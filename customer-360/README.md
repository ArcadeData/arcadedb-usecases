# Customer 360

Demonstrates ArcadeDB's multi-model capabilities by building a unified customer
view that combines all five pillars in a single database:

- **Graph traversal** -- identity resolution, churn risk scoring, cross-sell recommendations
- **Documents** -- fuzzy deduplication via cross-matching
- **Vectors** -- customer preference and product embeddings (LSM_VECTOR)
- **Full-text search** -- support ticket content indexing
- **Time-series** -- journey path analysis via event chains

Uses **OpenCypher** as the primary query language, with SQL MATCH for
graph patterns that require explicit hop control.

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

This creates the `Customer360` database, applies the schema, and inserts sample data.

### 3a. Run queries via curl

```bash
./queries/queries.sh
```

### 3b. Run queries via Java

```bash
cd java
mvn package -q
java -jar target/customer-360.jar
```

## Schema

| Type | Kind | Key properties |
|------|------|----------------|
| `Customer` | Vertex | `id`, `name`, `email`, `phone`, `status`, `prefVector`, `recentBehavior`, `baselineBehavior`, `lifetimeValue` |
| `Household` | Vertex | `id`, `name` |
| `Product` | Vertex | `id`, `name`, `category`, `price`, `embedding` |
| `Device` | Vertex | `id`, `deviceType`, `os` |
| `Address` | Vertex | `id`, `street`, `city`, `state`, `zip` |
| `Ticket` | Vertex | `id`, `subject`, `status`, `content` |
| `Campaign` | Vertex | `id`, `name`, `channel` |
| `Session` | Vertex | `id`, `startedAt` |
| `Event` | Vertex | `id`, `eventType`, `channel`, `page` |
| `Identifier` | Vertex | `id`, `identifierType`, `identifierValue` |
| `PURCHASED` | Edge | Customer -> Product (`purchasedAt`) |
| `LIVES_AT` | Edge | Customer -> Address |
| `USED` | Edge | Customer -> Device |
| `MEMBER_OF` | Edge | Customer -> Household |
| `OPENED` | Edge | Customer -> Ticket |
| `CLICKED` | Edge | Customer -> Campaign |
| `REFERRED` | Edge | Customer -> Customer |
| `CONNECTED_TO` | Edge | Customer -> Customer |
| `OBSERVED_IN` | Edge | Identifier -> Session |
| `INTERACTED` | Edge | Customer -> Event |
| `FOLLOWED_BY` | Edge | Event -> Event |

The `Device`, `Address`, and `Campaign` types with their edges (`LIVES_AT`, `USED`, `CLICKED`) are populated in the sample data and available for extension but not exercised by the current queries.

## Query Patterns

| # | Pattern | Language | Description |
|---|---------|----------|-------------|
| 1 | Identity Resolution | SQL MATCH | 3-hop transitive link discovery via shared sessions |
| 2 | Fuzzy Deduplication | Cypher | Cross-match customers by shared phone number |
| 3 | Customer 360 View | Cypher | Unified profile: household, purchases, open tickets, LTV |
| 4 | Churn Risk Scoring | SQL MATCH | Churned-neighbor ratio in social network |
| 5 | Cross-Sell Recommendations | Cypher | Household + collaborative filtering |
| 6 | Journey Path Analysis | Cypher | Conversion paths: ad_click -> page_view -> purchase |

## Sample Data

- 6 customers (4 active, 2 churned) with 8-dimensional preference vectors
- 2 households, 6 products, 3 devices, 3 addresses
- 6 identifiers and 3 sessions for identity resolution
- 9 events forming 3 conversion paths
- 3 support tickets (1 open, 2 closed) with full-text indexed content
- Social graph edges (REFERRED, CONNECTED_TO) linking active to churned customers

## ArcadeDB Version Notes

This use case targets ArcadeDB **26.3.1**. Vector indexes use
`LSM_VECTOR METADATA { dimensions: 8, similarity: 'COSINE' }`.
Full-text search uses `FULL_TEXT` index on Ticket content.

## Reference

[ArcadeDB Customer 360 use case](https://arcadedb.com/customer-360.html)
