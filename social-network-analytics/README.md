# Social Network Analytics

Demonstrates materialized views (all 3 refresh modes), graph traversal,
time-series engagement tracking, and polyglot querying (SQL + OpenCypher)
in a single ArcadeDB database.

- **Materialized views** --- PERIODIC (trending dashboard), INCREMENTAL (post counts), MANUAL (influence scores)
- **Graph traversal** --- viral spread chains and community overlap
- **Time-series** --- post engagement growth over time
- **Polyglot querying** --- SQL for views/aggregations, OpenCypher for graph traversals

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

This creates the `SocialNetwork` database, applies the schema, inserts
sample data, and creates materialized views.

### 3a. Run queries via curl

```bash
./queries/queries.sh
```

### 3b. Run queries via Java

```bash
cd java
mvn package -q
java -jar target/social-network-analytics.jar
```

## Schema

### Vertex Types

| Type | Key properties |
|------|----------------|
| `User` | `name`, `handle`, `joinedAt`, `bio` |
| `Post` | `title`, `body`, `createdAt`, `category` |
| `Topic` | `name`, `description` |
| `Group` | `name`, `description`, `createdAt` |

### Edge Types

| Type | From -> To |
|------|-----------|
| `FOLLOWS` | User -> User |
| `CREATED` | User -> Post |
| `LIKED` | User -> Post |
| `SHARED` | User -> Post |
| `TAGGED` | Post -> Topic |
| `MEMBER_OF` | User -> Group |

### Document Types

| Type | Key properties |
|------|----------------|
| `EngagementMetric` | `postRid`, `recordedAt`, `likes`, `shares`, `comments` |

## Materialized Views

| View | Refresh Mode | Purpose |
|------|-------------|---------|
| `TrendingPosts` | PERIODIC (1 min) | Aggregates engagement into trending scores |
| `UserPostCounts` | INCREMENTAL | Counts posts per user, updates on each commit |
| `InfluenceScores` | MANUAL | Follower counts per user, refreshed on demand |

## Query Patterns

| # | Pattern | Language | Signal type |
|---|---------|----------|-------------|
| 1 | Trending Content Dashboard | SQL | Materialized view (PERIODIC) |
| 2 | Engagement Time-Series | SQL | Time-series |
| 3 | Influence Leaderboard | SQL | Materialized view (MANUAL) |
| 4 | Viral Spread Chain | OpenCypher | Graph traversal |
| 5 | Community Overlap | OpenCypher | Graph traversal |

## Sample Data

- 8 users, 12 posts, 4 topics, 3 groups
- ~20 follow edges, ~25 likes, ~10 shares, ~15 tags, ~12 memberships
- 36 engagement metric time-series records (3 snapshots per post)

## ArcadeDB Version Notes

This use case targets ArcadeDB **26.3.1**.

- `opencypher` and `cypher` are aliases for the language identifier
- Edge endpoint traversal in SQL requires `@out.property` / `@in.property` syntax
- DATETIME properties require `'YYYY-MM-DD HH:MM:SS'` format (ISO8601 `T` separator not supported)
