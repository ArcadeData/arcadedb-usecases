# Social Network Analytics Use Case — Design

**Date:** 2026-03-06
**Branch:** feat/social-network-analytics
**ArcadeDB version:** 26.3.1

## Overview

A social network analytics platform demonstrating ArcadeDB's materialized views (all three refresh modes), graph traversal, time-series engagement tracking, and polyglot querying (SQL + OpenCypher). Users create posts, follow each other, join groups, and interact with content — materialized views pre-compute trending posts, user post counts, and influence scores.

**Key ArcadeDB features:** Materialized views (MANUAL, INCREMENTAL, PERIODIC), Graph traversal, Time-series, Polyglot querying (SQL + OpenCypher)

## Repository Structure

```
social-network-analytics/
├── docker-compose.yml
├── setup.sh
├── sql/
│   ├── 01-schema.sql
│   ├── 02-data.sql
│   └── 03-materialized-views.sql
├── queries/
│   └── queries.sh
├── java/
│   ├── pom.xml
│   └── src/main/java/com/arcadedb/examples/SocialNetworkAnalytics.java
└── README.md
```

## Docker Compose

- Single service: `arcadedata/arcadedb:26.3.1`
- HTTP API port exposed: `2480`
- Root password via `JAVA_OPTS: "-Darcadedb.server.rootPassword=arcadedb"`
- Healthcheck: `curl -sf http://localhost:2480/api/v1/ready`, interval 5s, retries 20

## Schema (`sql/01-schema.sql`)

### Vertex Types (4)

| Type | Properties | Purpose |
|------|-----------|---------|
| `User` | `name STRING`, `handle STRING`, `joinedAt DATETIME`, `bio STRING` | People in the network |
| `Post` | `title STRING`, `body STRING`, `createdAt DATETIME`, `category STRING` | Content created by users |
| `Topic` | `name STRING`, `description STRING` | Hashtags/topics for categorization |
| `Group` | `name STRING`, `description STRING`, `createdAt DATETIME` | Communities |

### Edge Types (6)

| Type | From -> To | Purpose |
|------|-----------|---------|
| `FOLLOWS` | User -> User | Social graph |
| `CREATED` | User -> Post | Authorship |
| `LIKED` | User -> Post | Engagement |
| `SHARED` | User -> Post | Content spread |
| `TAGGED` | Post -> Topic | Content categorization |
| `MEMBER_OF` | User -> Group | Community membership |

### Document Type (1)

| Type | Properties | Purpose |
|------|-----------|---------|
| `EngagementMetric` | `postRid STRING`, `timestamp DATETIME`, `likes INTEGER`, `shares INTEGER`, `comments INTEGER` | Time-series engagement snapshots per post |

## Materialized Views (`sql/03-materialized-views.sql`)

Applied after data load so the initial refresh has data to work with.

### 1. `TrendingPosts` — PERIODIC (every 1 minute)

Pre-computes hottest posts by aggregating engagement metrics. Periodic refresh suits trending content: frequent enough for dashboards, without post-commit overhead on every interaction.

```sql
CREATE MATERIALIZED VIEW TrendingPosts
  AS SELECT postRid, sum(likes) AS totalLikes, sum(shares) AS totalShares,
            sum(comments) AS totalComments,
            sum(likes) + sum(shares) * 2 + sum(comments) * 3 AS score
     FROM EngagementMetric
     GROUP BY postRid
  REFRESH EVERY 1 MINUTE
```

### 2. `UserPostCounts` — INCREMENTAL (post-commit)

Tracks how many posts each user has created. Incremental refresh is the right fit — simple, low-cost aggregation that should always be current.

```sql
CREATE MATERIALIZED VIEW UserPostCounts
  AS SELECT in AS userRid, count(*) AS postCount
     FROM CREATED
     GROUP BY in
  REFRESH INCREMENTAL
```

### 3. `InfluenceScores` — MANUAL

Computes a composite influence score per user: follower count + total engagement on their posts. Expensive computation best refreshed on demand after bulk loads or before generating reports.

```sql
CREATE MATERIALIZED VIEW InfluenceScores
  AS SELECT u.name AS userName, u.handle AS handle,
            count(DISTINCT f.@rid) AS followers,
            sum(e.likes + e.shares + e.comments) AS totalEngagement
     FROM User u
     LET followers = (SELECT FROM FOLLOWS WHERE in = u.@rid),
         posts = (SELECT FROM CREATED WHERE out = u.@rid),
         engagement = (SELECT FROM EngagementMetric WHERE postRid IN posts.in)
     GROUP BY u.name, u.handle
  REFRESH MANUAL
```

*Note: The exact SQL for InfluenceScores may need adjustment during implementation based on ArcadeDB's LET/subquery support in materialized view definitions. Will validate and simplify as needed.*

## Time-Series Design

`EngagementMetric` is a document type used as a time-series bucket. Each record is a snapshot of engagement on a post at a point in time.

Multiple entries per post across several timestamps (hour 1, 2, 3) show engagement growing over time, feeding the `TrendingPosts` materialized view and enabling time-series drill-down queries.

## Queries — Polyglot Strategy

Five labeled sections mixing SQL and OpenCypher based on what each language does best.

### SQL Queries (materialized views, time-series, aggregations)

**1. Trending Content Dashboard** — reads from the periodic materialized view
```sql
SELECT * FROM TrendingPosts ORDER BY score DESC LIMIT 10
```

**2. Engagement Time-Series** — drill into a post's engagement over time
```sql
SELECT timestamp, likes, shares, comments
FROM EngagementMetric WHERE postRid = '<rid>' ORDER BY timestamp
```

**3. Influence Leaderboard** — reads from the manual-refresh view
```sql
SELECT * FROM InfluenceScores ORDER BY totalEngagement DESC LIMIT 5
```

### OpenCypher Queries (graph traversals)

**4. Viral Spread Chain** — how a post propagated through shares
```cypher
MATCH (author:User)-[:CREATED]->(p:Post)<-[:SHARED]-(sharer:User)<-[:FOLLOWS]-(audience:User)
WHERE id(p) = '<rid>'
RETURN author.name, sharer.name, collect(audience.name) AS reachedAudience
```

**5. Community Overlap** — users in the same group who follow each other
```cypher
MATCH (a:User)-[:MEMBER_OF]->(g:Group)<-[:MEMBER_OF]-(b:User)
WHERE (a)-[:FOLLOWS]->(b)
RETURN g.name, a.name, b.name
```

## Sample Data (`sql/02-data.sql`)

### Volumes

| Type | Count | Notes |
|------|-------|-------|
| User | 8 | Mix of high-influence and casual users |
| Post | 12 | Spread across users, 2-3 categories |
| Topic | 4 | Tech, Music, Sports, Travel |
| Group | 3 | Developers, Photographers, Gamers |
| FOLLOWS | ~20 | Asymmetric — some users have many followers |
| CREATED | 12 | One per post |
| LIKED | ~25 | Skewed — some posts get many likes |
| SHARED | ~10 | Concentrated on "viral" posts |
| TAGGED | ~15 | Posts tagged with 1-2 topics |
| MEMBER_OF | ~12 | Users belong to 1-2 groups |
| EngagementMetric | ~36 | 3 time-series snapshots per post |

### Data Story

- **Alice** and **Bob** are high-influence users with many followers and popular posts
- Alice's post about "AI Trends" goes viral — many shares, growing engagement over time
- A cluster of users in the Developers group follow each other, creating community overlap
- Engagement metrics show clear trends: some posts peak early, others grow steadily

## Java Program

`SocialNetworkAnalytics.java` follows the existing `tryRun()`/`printHeader()` pattern using HTTP API (`arcadedb-network`). Five query sections matching the five shell query sections. Uses `query "sql"` for materialized view and time-series queries, `query "opencypher"` for graph traversals.

## CI Workflow

`.github/workflows/social-network-analytics.yml` following the standard matrix pattern:

```yaml
matrix:
  runner: [curl, java]
```

Steps: checkout, setup Java 21 (gated), cache ~/.m2 (gated), docker compose up, setup.sh, run queries or build/run fat JAR, docker compose down (always).

## Success Criteria

1. All three materialized view refresh modes demonstrated and working
2. Materialized views return correct pre-computed data when queried
3. Time-series engagement data feeds into the TrendingPosts view
4. SQL queries read from materialized views; OpenCypher queries traverse the graph
5. Both curl and Java runners pass in CI
