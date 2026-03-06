# Social Network Analytics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a social network analytics use case demonstrating materialized views (all 3 refresh modes), graph traversal, time-series engagement tracking, and polyglot querying (SQL + OpenCypher).

**Architecture:** Graph model of users, posts, topics, and groups with engagement time-series feeding three materialized views (PERIODIC trending, INCREMENTAL post counts, MANUAL influence scores). Queries split between SQL (views, time-series) and OpenCypher (graph traversals).

**Tech Stack:** ArcadeDB 26.3.1, HTTP API (`arcadedb-network`), Java 21, Maven, Docker Compose

**Design doc:** `docs/plans/2026-03-06-social-network-analytics-design.md`

---

### Task 1: Docker Compose

**Files:**
- Create: `social-network-analytics/docker-compose.yml`

**Step 1: Create the Docker Compose file**

```yaml
services:
  arcadedb:
    image: arcadedata/arcadedb:26.3.1
    ports:
      - "2480:2480"
    environment:
      JAVA_OPTS: "-Darcadedb.server.rootPassword=arcadedb"
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:2480/api/v1/ready"]
      interval: 5s
      timeout: 3s
      retries: 20
      start_period: 10s
```

**Step 2: Verify it starts**

Run from `social-network-analytics/`:
```bash
docker compose up -d && docker compose ps
```
Expected: arcadedb service healthy.

```bash
docker compose down
```

**Step 3: Commit**

```bash
git add social-network-analytics/docker-compose.yml
git commit -m "feat(social-network-analytics): add Docker Compose"
```

---

### Task 2: Schema SQL

**Files:**
- Create: `social-network-analytics/sql/01-schema.sql`

**Step 1: Write the schema file**

One statement per line. No trailing semicolons required (setup.sh strips them). Vertex types for the graph, document type for time-series, edge types for relationships.

```sql
CREATE VERTEX TYPE User IF NOT EXISTS
CREATE PROPERTY User.name IF NOT EXISTS STRING
CREATE PROPERTY User.handle IF NOT EXISTS STRING
CREATE PROPERTY User.joinedAt IF NOT EXISTS DATETIME
CREATE PROPERTY User.bio IF NOT EXISTS STRING
CREATE INDEX IF NOT EXISTS ON User (handle) UNIQUE
CREATE VERTEX TYPE Post IF NOT EXISTS
CREATE PROPERTY Post.title IF NOT EXISTS STRING
CREATE PROPERTY Post.body IF NOT EXISTS STRING
CREATE PROPERTY Post.createdAt IF NOT EXISTS DATETIME
CREATE PROPERTY Post.category IF NOT EXISTS STRING
CREATE VERTEX TYPE Topic IF NOT EXISTS
CREATE PROPERTY Topic.name IF NOT EXISTS STRING
CREATE PROPERTY Topic.description IF NOT EXISTS STRING
CREATE INDEX IF NOT EXISTS ON Topic (name) UNIQUE
CREATE VERTEX TYPE Group IF NOT EXISTS
CREATE PROPERTY Group.name IF NOT EXISTS STRING
CREATE PROPERTY Group.description IF NOT EXISTS STRING
CREATE PROPERTY Group.createdAt IF NOT EXISTS DATETIME
CREATE DOCUMENT TYPE EngagementMetric IF NOT EXISTS
CREATE PROPERTY EngagementMetric.postRid IF NOT EXISTS STRING
CREATE PROPERTY EngagementMetric.timestamp IF NOT EXISTS DATETIME
CREATE PROPERTY EngagementMetric.likes IF NOT EXISTS INTEGER
CREATE PROPERTY EngagementMetric.shares IF NOT EXISTS INTEGER
CREATE PROPERTY EngagementMetric.comments IF NOT EXISTS INTEGER
CREATE EDGE TYPE FOLLOWS IF NOT EXISTS
CREATE EDGE TYPE CREATED IF NOT EXISTS
CREATE EDGE TYPE LIKED IF NOT EXISTS
CREATE EDGE TYPE SHARED IF NOT EXISTS
CREATE EDGE TYPE TAGGED IF NOT EXISTS
CREATE EDGE TYPE MEMBER_OF IF NOT EXISTS
```

**Step 2: Commit**

```bash
git add social-network-analytics/sql/01-schema.sql
git commit -m "feat(social-network-analytics): add schema SQL"
```

---

### Task 3: Sample Data SQL

**Files:**
- Create: `social-network-analytics/sql/02-data.sql`

**Step 1: Write the data file**

One statement per line. Uses `INSERT INTO ... SET ...` for documents/vertices, `CREATE EDGE ... FROM (SELECT ...) TO (SELECT ...)` for edges. RIDs are not predictable, so edges reference vertices via unique properties.

**Data story:**
- 8 users: Alice (influencer), Bob (influencer), Charlie, Diana, Eve, Frank, Grace, Hank
- 12 posts across users, categories: Tech, Music, Sports, Travel
- 4 topics: Tech, Music, Sports, Travel
- 3 groups: Developers, Photographers, Gamers
- Asymmetric FOLLOWS: Alice and Bob have many followers
- LIKED edges skewed toward Alice's "AI Trends" post (viral)
- SHARED edges concentrated on viral posts
- TAGGED: 1-2 topics per post
- MEMBER_OF: users in 1-2 groups, Developers group has a cluster of mutual followers
- EngagementMetric: 3 timestamps per post (hour 1, 2, 3) showing growth

```sql
-- Users
INSERT INTO User SET name = 'Alice', handle = 'alice', joinedAt = '2025-01-15T10:00:00Z', bio = 'Tech blogger and AI enthusiast'
INSERT INTO User SET name = 'Bob', handle = 'bob', joinedAt = '2025-02-20T14:30:00Z', bio = 'Music producer and photographer'
INSERT INTO User SET name = 'Charlie', handle = 'charlie', joinedAt = '2025-03-10T09:00:00Z', bio = 'Full-stack developer'
INSERT INTO User SET name = 'Diana', handle = 'diana', joinedAt = '2025-04-05T11:00:00Z', bio = 'Sports journalist'
INSERT INTO User SET name = 'Eve', handle = 'eve', joinedAt = '2025-05-12T08:00:00Z', bio = 'Travel photographer'
INSERT INTO User SET name = 'Frank', handle = 'frank', joinedAt = '2025-06-01T16:00:00Z', bio = 'Indie game developer'
INSERT INTO User SET name = 'Grace', handle = 'grace', joinedAt = '2025-07-20T12:00:00Z', bio = 'Data scientist'
INSERT INTO User SET name = 'Hank', handle = 'hank', joinedAt = '2025-08-15T10:00:00Z', bio = 'Casual user'
-- Topics
INSERT INTO Topic SET name = 'Tech', description = 'Technology and software'
INSERT INTO Topic SET name = 'Music', description = 'Music production and culture'
INSERT INTO Topic SET name = 'Sports', description = 'Sports news and analysis'
INSERT INTO Topic SET name = 'Travel', description = 'Travel stories and tips'
-- Groups
INSERT INTO Group SET name = 'Developers', description = 'Software development community', createdAt = '2025-01-01T00:00:00Z'
INSERT INTO Group SET name = 'Photographers', description = 'Photography enthusiasts', createdAt = '2025-02-01T00:00:00Z'
INSERT INTO Group SET name = 'Gamers', description = 'Gaming community', createdAt = '2025-03-01T00:00:00Z'
-- Posts (12 posts across users)
INSERT INTO Post SET title = 'AI Trends in 2026', body = 'A deep dive into the latest AI developments', createdAt = '2026-03-01T09:00:00Z', category = 'Tech'
INSERT INTO Post SET title = 'Building REST APIs', body = 'Best practices for API design', createdAt = '2026-03-01T10:00:00Z', category = 'Tech'
INSERT INTO Post SET title = 'Guitar Techniques', body = 'Advanced fingerpicking patterns', createdAt = '2026-03-01T11:00:00Z', category = 'Music'
INSERT INTO Post SET title = 'Concert Review', body = 'Last night at the jazz festival', createdAt = '2026-03-01T12:00:00Z', category = 'Music'
INSERT INTO Post SET title = 'Marathon Training', body = 'My 16-week training plan', createdAt = '2026-03-02T08:00:00Z', category = 'Sports'
INSERT INTO Post SET title = 'Database Performance', body = 'Tuning queries for multi-model databases', createdAt = '2026-03-02T09:00:00Z', category = 'Tech'
INSERT INTO Post SET title = 'Tokyo Travel Guide', body = 'Hidden gems in Shibuya and Shinjuku', createdAt = '2026-03-02T10:00:00Z', category = 'Travel'
INSERT INTO Post SET title = 'Game Dev Tips', body = 'Optimizing sprite rendering', createdAt = '2026-03-02T11:00:00Z', category = 'Tech'
INSERT INTO Post SET title = 'Vinyl Collecting', body = 'Finding rare pressings at local shops', createdAt = '2026-03-03T09:00:00Z', category = 'Music'
INSERT INTO Post SET title = 'Rock Climbing Basics', body = 'Getting started with bouldering', createdAt = '2026-03-03T10:00:00Z', category = 'Sports'
INSERT INTO Post SET title = 'Backpacking Europe', body = 'Budget tips for 30 days across 10 countries', createdAt = '2026-03-03T11:00:00Z', category = 'Travel'
INSERT INTO Post SET title = 'Open Source Databases', body = 'Why multi-model is the future', createdAt = '2026-03-03T12:00:00Z', category = 'Tech'
-- CREATED edges (User -> Post, authorship)
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Post WHERE title = 'Building REST APIs')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Post WHERE title = 'Open Source Databases')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'Guitar Techniques')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'Concert Review')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'Vinyl Collecting')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Post WHERE title = 'Database Performance')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Post WHERE title = 'Marathon Training')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Post WHERE title = 'Rock Climbing Basics')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM Post WHERE title = 'Tokyo Travel Guide')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM Post WHERE title = 'Backpacking Europe')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM Post WHERE title = 'Game Dev Tips')
-- FOLLOWS edges (asymmetric — Alice and Bob are popular)
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM User WHERE handle = 'alice')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM User WHERE handle = 'alice')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM User WHERE handle = 'alice')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM User WHERE handle = 'alice')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM User WHERE handle = 'alice')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM User WHERE handle = 'alice')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM User WHERE handle = 'alice')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM User WHERE handle = 'bob')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM User WHERE handle = 'bob')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM User WHERE handle = 'bob')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM User WHERE handle = 'bob')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM User WHERE handle = 'bob')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM User WHERE handle = 'charlie')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM User WHERE handle = 'charlie')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM User WHERE handle = 'grace')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM User WHERE handle = 'charlie')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM User WHERE handle = 'frank')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM User WHERE handle = 'frank')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM User WHERE handle = 'diana')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM User WHERE handle = 'eve')
-- LIKED edges (skewed toward viral post "AI Trends in 2026")
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Post WHERE title = 'Guitar Techniques')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Post WHERE title = 'Guitar Techniques')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM Post WHERE title = 'Guitar Techniques')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Post WHERE title = 'Concert Review')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Post WHERE title = 'Concert Review')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Post WHERE title = 'Database Performance')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM Post WHERE title = 'Database Performance')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Post WHERE title = 'Marathon Training')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'Tokyo Travel Guide')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Post WHERE title = 'Tokyo Travel Guide')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM Post WHERE title = 'Tokyo Travel Guide')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM Post WHERE title = 'Game Dev Tips')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM Post WHERE title = 'Game Dev Tips')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'Open Source Databases')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Post WHERE title = 'Open Source Databases')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM Post WHERE title = 'Open Source Databases')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM Post WHERE title = 'Open Source Databases')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM Post WHERE title = 'Backpacking Europe')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM Post WHERE title = 'Backpacking Europe')
-- SHARED edges (concentrated on viral posts)
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Post WHERE title = 'Guitar Techniques')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Post WHERE title = 'Guitar Techniques')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Post WHERE title = 'Open Source Databases')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM Post WHERE title = 'Tokyo Travel Guide')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'Marathon Training')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM Post WHERE title = 'Backpacking Europe')
-- TAGGED edges (Post -> Topic, 1-2 topics per post)
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'AI Trends in 2026') TO (SELECT FROM Topic WHERE name = 'Tech')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Building REST APIs') TO (SELECT FROM Topic WHERE name = 'Tech')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Guitar Techniques') TO (SELECT FROM Topic WHERE name = 'Music')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Concert Review') TO (SELECT FROM Topic WHERE name = 'Music')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Marathon Training') TO (SELECT FROM Topic WHERE name = 'Sports')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Database Performance') TO (SELECT FROM Topic WHERE name = 'Tech')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Tokyo Travel Guide') TO (SELECT FROM Topic WHERE name = 'Travel')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Game Dev Tips') TO (SELECT FROM Topic WHERE name = 'Tech')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Vinyl Collecting') TO (SELECT FROM Topic WHERE name = 'Music')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Rock Climbing Basics') TO (SELECT FROM Topic WHERE name = 'Sports')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Backpacking Europe') TO (SELECT FROM Topic WHERE name = 'Travel')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Open Source Databases') TO (SELECT FROM Topic WHERE name = 'Tech')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Game Dev Tips') TO (SELECT FROM Topic WHERE name = 'Music')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Rock Climbing Basics') TO (SELECT FROM Topic WHERE name = 'Travel')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Concert Review') TO (SELECT FROM Topic WHERE name = 'Travel')
-- MEMBER_OF edges (User -> Group, Developers has mutual-follow cluster)
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Group WHERE name = 'Developers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Group WHERE name = 'Developers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM Group WHERE name = 'Developers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM Group WHERE name = 'Developers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Group WHERE name = 'Photographers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM Group WHERE name = 'Photographers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Group WHERE name = 'Photographers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM Group WHERE name = 'Gamers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM Group WHERE name = 'Gamers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Group WHERE name = 'Gamers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM Group WHERE name = 'Gamers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Group WHERE name = 'Gamers')
-- EngagementMetric time-series (3 snapshots per post: hour 1, 2, 3)
-- AI Trends in 2026 (viral — rapid growth)
INSERT INTO EngagementMetric SET postRid = 'ai-trends-2026', timestamp = '2026-03-01T10:00:00Z', likes = 5, shares = 2, comments = 3
INSERT INTO EngagementMetric SET postRid = 'ai-trends-2026', timestamp = '2026-03-01T11:00:00Z', likes = 15, shares = 8, comments = 10
INSERT INTO EngagementMetric SET postRid = 'ai-trends-2026', timestamp = '2026-03-01T12:00:00Z', likes = 30, shares = 15, comments = 20
-- Building REST APIs (steady)
INSERT INTO EngagementMetric SET postRid = 'building-rest-apis', timestamp = '2026-03-01T11:00:00Z', likes = 3, shares = 1, comments = 2
INSERT INTO EngagementMetric SET postRid = 'building-rest-apis', timestamp = '2026-03-01T12:00:00Z', likes = 5, shares = 2, comments = 3
INSERT INTO EngagementMetric SET postRid = 'building-rest-apis', timestamp = '2026-03-01T13:00:00Z', likes = 7, shares = 2, comments = 4
-- Guitar Techniques (moderate growth)
INSERT INTO EngagementMetric SET postRid = 'guitar-techniques', timestamp = '2026-03-01T12:00:00Z', likes = 4, shares = 2, comments = 1
INSERT INTO EngagementMetric SET postRid = 'guitar-techniques', timestamp = '2026-03-01T13:00:00Z', likes = 8, shares = 4, comments = 3
INSERT INTO EngagementMetric SET postRid = 'guitar-techniques', timestamp = '2026-03-01T14:00:00Z', likes = 12, shares = 6, comments = 5
-- Concert Review (peaks early then plateaus)
INSERT INTO EngagementMetric SET postRid = 'concert-review', timestamp = '2026-03-01T13:00:00Z', likes = 8, shares = 1, comments = 5
INSERT INTO EngagementMetric SET postRid = 'concert-review', timestamp = '2026-03-01T14:00:00Z', likes = 10, shares = 1, comments = 6
INSERT INTO EngagementMetric SET postRid = 'concert-review', timestamp = '2026-03-01T15:00:00Z', likes = 11, shares = 1, comments = 6
-- Marathon Training (slow and steady)
INSERT INTO EngagementMetric SET postRid = 'marathon-training', timestamp = '2026-03-02T09:00:00Z', likes = 2, shares = 1, comments = 1
INSERT INTO EngagementMetric SET postRid = 'marathon-training', timestamp = '2026-03-02T10:00:00Z', likes = 4, shares = 2, comments = 2
INSERT INTO EngagementMetric SET postRid = 'marathon-training', timestamp = '2026-03-02T11:00:00Z', likes = 6, shares = 3, comments = 3
-- Database Performance (moderate)
INSERT INTO EngagementMetric SET postRid = 'database-performance', timestamp = '2026-03-02T10:00:00Z', likes = 3, shares = 1, comments = 2
INSERT INTO EngagementMetric SET postRid = 'database-performance', timestamp = '2026-03-02T11:00:00Z', likes = 6, shares = 2, comments = 4
INSERT INTO EngagementMetric SET postRid = 'database-performance', timestamp = '2026-03-02T12:00:00Z', likes = 8, shares = 3, comments = 5
-- Tokyo Travel Guide (moderate growth)
INSERT INTO EngagementMetric SET postRid = 'tokyo-travel-guide', timestamp = '2026-03-02T11:00:00Z', likes = 5, shares = 2, comments = 3
INSERT INTO EngagementMetric SET postRid = 'tokyo-travel-guide', timestamp = '2026-03-02T12:00:00Z', likes = 9, shares = 4, comments = 5
INSERT INTO EngagementMetric SET postRid = 'tokyo-travel-guide', timestamp = '2026-03-02T13:00:00Z', likes = 12, shares = 5, comments = 7
-- Game Dev Tips (niche but engaged)
INSERT INTO EngagementMetric SET postRid = 'game-dev-tips', timestamp = '2026-03-02T12:00:00Z', likes = 2, shares = 0, comments = 3
INSERT INTO EngagementMetric SET postRid = 'game-dev-tips', timestamp = '2026-03-02T13:00:00Z', likes = 4, shares = 1, comments = 5
INSERT INTO EngagementMetric SET postRid = 'game-dev-tips', timestamp = '2026-03-02T14:00:00Z', likes = 5, shares = 1, comments = 7
-- Vinyl Collecting (low engagement)
INSERT INTO EngagementMetric SET postRid = 'vinyl-collecting', timestamp = '2026-03-03T10:00:00Z', likes = 2, shares = 0, comments = 1
INSERT INTO EngagementMetric SET postRid = 'vinyl-collecting', timestamp = '2026-03-03T11:00:00Z', likes = 3, shares = 1, comments = 1
INSERT INTO EngagementMetric SET postRid = 'vinyl-collecting', timestamp = '2026-03-03T12:00:00Z', likes = 4, shares = 1, comments = 2
-- Rock Climbing Basics (moderate)
INSERT INTO EngagementMetric SET postRid = 'rock-climbing-basics', timestamp = '2026-03-03T11:00:00Z', likes = 3, shares = 1, comments = 2
INSERT INTO EngagementMetric SET postRid = 'rock-climbing-basics', timestamp = '2026-03-03T12:00:00Z', likes = 5, shares = 2, comments = 3
INSERT INTO EngagementMetric SET postRid = 'rock-climbing-basics', timestamp = '2026-03-03T13:00:00Z', likes = 7, shares = 2, comments = 4
-- Backpacking Europe (grows steadily)
INSERT INTO EngagementMetric SET postRid = 'backpacking-europe', timestamp = '2026-03-03T12:00:00Z', likes = 4, shares = 2, comments = 2
INSERT INTO EngagementMetric SET postRid = 'backpacking-europe', timestamp = '2026-03-03T13:00:00Z', likes = 8, shares = 4, comments = 4
INSERT INTO EngagementMetric SET postRid = 'backpacking-europe', timestamp = '2026-03-03T14:00:00Z', likes = 13, shares = 6, comments = 6
-- Open Source Databases (strong engagement)
INSERT INTO EngagementMetric SET postRid = 'open-source-databases', timestamp = '2026-03-03T13:00:00Z', likes = 6, shares = 3, comments = 4
INSERT INTO EngagementMetric SET postRid = 'open-source-databases', timestamp = '2026-03-03T14:00:00Z', likes = 12, shares = 5, comments = 7
INSERT INTO EngagementMetric SET postRid = 'open-source-databases', timestamp = '2026-03-03T15:00:00Z', likes = 18, shares = 8, comments = 10
```

**Step 2: Commit**

```bash
git add social-network-analytics/sql/02-data.sql
git commit -m "feat(social-network-analytics): add sample data SQL"
```

---

### Task 4: Materialized Views SQL

**Files:**
- Create: `social-network-analytics/sql/03-materialized-views.sql`

**Step 1: Write the materialized views file**

Three views, one per refresh mode. These are applied after data load so the initial refresh populates them.

Note: The InfluenceScores view uses a simplified query that avoids LET subqueries (ArcadeDB quirk — `LET $var = (SELECT ... GROUP BY ...)` is not supported). The exact query syntax will be validated during Task 6 testing and adjusted as needed.

```sql
-- TrendingPosts: PERIODIC refresh every 1 minute
-- Aggregates engagement metrics into a trending score per post
CREATE MATERIALIZED VIEW TrendingPosts AS SELECT postRid, sum(likes) AS totalLikes, sum(shares) AS totalShares, sum(comments) AS totalComments, sum(likes) + sum(shares) * 2 + sum(comments) * 3 AS score FROM EngagementMetric GROUP BY postRid REFRESH EVERY 1 MINUTE
-- UserPostCounts: INCREMENTAL refresh (updates after each commit)
-- Counts posts per user by counting outgoing CREATED edges
CREATE MATERIALIZED VIEW UserPostCounts AS SELECT out.handle AS handle, out.name AS userName, count(*) AS postCount FROM CREATED GROUP BY out.handle, out.name REFRESH INCREMENTAL
-- InfluenceScores: MANUAL refresh (on demand)
-- Computes follower count per user (engagement correlation done at query time)
CREATE MATERIALIZED VIEW InfluenceScores AS SELECT in.name AS userName, in.handle AS handle, count(*) AS followers FROM FOLLOWS GROUP BY in.name, in.handle REFRESH MANUAL
```

**Implementation note:** The InfluenceScores view is simplified to count followers only. The full influence score (followers + engagement) is computed at query time by joining InfluenceScores with EngagementMetric data. This avoids complex cross-type subqueries in the materialized view definition.

**Step 2: Commit**

```bash
git add social-network-analytics/sql/03-materialized-views.sql
git commit -m "feat(social-network-analytics): add materialized views SQL"
```

---

### Task 5: setup.sh

**Files:**
- Create: `social-network-analytics/setup.sh`

**Step 1: Write setup.sh**

Copy pattern from `realtime-analytics/setup.sh`, change `DB_NAME` to `SocialNetwork`, apply 3 SQL files.

```bash
#!/usr/bin/env bash
set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
DB_NAME="SocialNetwork"

# ── Wait for ArcadeDB ─────────────────────────────────────────────────────────
echo "Waiting for ArcadeDB at ${ARCADEDB_URL}..."
until curl -sf -u "${ARCADEDB_USER}:${ARCADEDB_PASS}" \
    "${ARCADEDB_URL}/api/v1/ready" > /dev/null 2>&1; do
  sleep 2
done
echo "ArcadeDB is ready."

# ── Create database ───────────────────────────────────────────────────────────
echo "Creating database ${DB_NAME}..."
curl -sf -u "${ARCADEDB_USER}:${ARCADEDB_PASS}" \
  -X POST "${ARCADEDB_URL}/api/v1/server" \
  -H "Content-Type: application/json" \
  -d "{\"command\": \"create database ${DB_NAME}\"}" > /dev/null || true
echo "Database ready."

# ── Helper: send one SQL statement ───────────────────────────────────────────
send_sql() {
  local stmt="$1"
  jq -cn --arg cmd "$stmt" '{"language":"sql","command":$cmd}' \
    | curl -sf -u "${ARCADEDB_USER}:${ARCADEDB_PASS}" \
        -X POST "${ARCADEDB_URL}/api/v1/command/${DB_NAME}" \
        -H "Content-Type: application/json" \
        -d @- > /dev/null
}

# ── Apply a SQL file (one statement per line) ─────────────────────────────────
apply_file() {
  local file="$1"
  echo "Applying ${file}..."
  while IFS= read -r line || [[ -n "$line" ]]; do
    # skip blank lines and SQL comments
    [[ -z "${line//[[:space:]]/}" || "$line" =~ ^[[:space:]]*-- ]] && continue
    send_sql "${line%%;}"
  done < "$file"
  echo "Done: ${file}"
}

apply_file "sql/01-schema.sql"
apply_file "sql/02-data.sql"
apply_file "sql/03-materialized-views.sql"

echo ""
echo "Setup complete. ${DB_NAME} is ready."
```

**Step 2: Make it executable**

```bash
chmod +x social-network-analytics/setup.sh
```

**Step 3: Commit**

```bash
git add social-network-analytics/setup.sh
git commit -m "feat(social-network-analytics): add setup script"
```

---

### Task 6: Integration Test — Schema, Data, and Materialized Views

**Step 1: Start ArcadeDB and run setup**

```bash
cd social-network-analytics
docker compose up -d
./setup.sh
```

Expected: All three SQL files applied without errors.

**Step 2: Verify materialized views exist and have data**

```bash
# Check TrendingPosts has data
curl -sf -u root:arcadedb -X POST \
  'http://localhost:2480/api/v1/query/SocialNetwork' \
  -H 'Content-Type: application/json' \
  -d '{"language":"sql","command":"SELECT count(*) AS cnt FROM TrendingPosts"}' | jq '.result'

# Check UserPostCounts has data
curl -sf -u root:arcadedb -X POST \
  'http://localhost:2480/api/v1/query/SocialNetwork' \
  -H 'Content-Type: application/json' \
  -d '{"language":"sql","command":"SELECT count(*) AS cnt FROM UserPostCounts"}' | jq '.result'

# Check InfluenceScores has data (needs manual refresh first)
curl -sf -u root:arcadedb -X POST \
  'http://localhost:2480/api/v1/command/SocialNetwork' \
  -H 'Content-Type: application/json' \
  -d '{"language":"sql","command":"REFRESH MATERIALIZED VIEW InfluenceScores"}' | jq
curl -sf -u root:arcadedb -X POST \
  'http://localhost:2480/api/v1/query/SocialNetwork' \
  -H 'Content-Type: application/json' \
  -d '{"language":"sql","command":"SELECT count(*) AS cnt FROM InfluenceScores"}' | jq '.result'
```

Expected: TrendingPosts count = 12 (one row per post), UserPostCounts count = 7 (7 users with posts — Hank and Grace have none), InfluenceScores count > 0. Adjust SQL in Task 2/4 if results don't match.

**Step 3: Verify OpenCypher works**

```bash
curl -sf -u root:arcadedb -X POST \
  'http://localhost:2480/api/v1/query/SocialNetwork' \
  -H 'Content-Type: application/json' \
  -d '{"language":"opencypher","command":"MATCH (u:User) RETURN count(u)"}' | jq '.result'
```

Expected: count = 8.

**Step 4: Tear down**

```bash
docker compose down
```

**Step 5: Fix any SQL issues found in Steps 2-3, amend commits if needed**

---

### Task 7: queries.sh

**Files:**
- Create: `social-network-analytics/queries/queries.sh`

**Step 1: Write queries.sh**

Five query sections: 3 SQL (materialized views + time-series), 2 OpenCypher (graph traversals). The InfluenceScores view needs a manual refresh before querying.

```bash
#!/usr/bin/env bash
# Social Network Analytics — all five query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="SocialNetwork"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"
COMMAND_URL="${ARCADEDB_URL}/api/v1/command/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

command() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$COMMAND_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Trending Content Dashboard (Materialized View — PERIODIC) ==="
echo "Read pre-computed trending scores from the TrendingPosts materialized view."
echo ""
query "sql" "
SELECT postRid, totalLikes, totalShares, totalComments, score
FROM TrendingPosts
ORDER BY score DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Engagement Time-Series ==="
echo "Drill into the viral post's engagement growth over time."
echo ""
query "sql" "
SELECT timestamp, likes, shares, comments
FROM EngagementMetric
WHERE postRid = 'ai-trends-2026'
ORDER BY timestamp
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Influence Leaderboard (Materialized View — MANUAL) ==="
echo "Refresh and query the InfluenceScores view for top users by follower count."
echo ""
command "sql" "REFRESH MATERIALIZED VIEW InfluenceScores"
echo "InfluenceScores refreshed."
echo ""
query "sql" "
SELECT userName, handle, followers
FROM InfluenceScores
ORDER BY followers DESC
LIMIT 5
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Viral Spread Chain (OpenCypher — Graph Traversal) ==="
echo "Trace how the AI Trends post spread: author -> sharers -> their followers."
echo ""
query "opencypher" "
MATCH (author:User)-[:CREATED]->(p:Post)<-[:SHARED]-(sharer:User)<-[:FOLLOWS]-(audience:User)
WHERE p.title = 'AI Trends in 2026'
RETURN author.name AS author, sharer.name AS sharer, collect(DISTINCT audience.name) AS reachedAudience
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: Community Overlap (OpenCypher — Graph Traversal) ==="
echo "Find users in the same group who also follow each other."
echo ""
query "opencypher" "
MATCH (a:User)-[:MEMBER_OF]->(g:Group)<-[:MEMBER_OF]-(b:User)
WHERE (a)-[:FOLLOWS]->(b) AND id(a) < id(b)
RETURN g.name AS group, a.name AS user1, b.name AS user2
ORDER BY g.name
"
```

**Step 2: Make it executable**

```bash
chmod +x social-network-analytics/queries/queries.sh
```

**Step 3: Test it**

```bash
cd social-network-analytics
docker compose up -d
./setup.sh
./queries/queries.sh
docker compose down
```

Expected: All 5 queries produce output. TrendingPosts shows "ai-trends-2026" at the top. InfluenceScores shows Alice with most followers. Viral spread chain shows sharers of AI Trends. Community overlap shows mutual followers in Developers group.

**Step 4: Commit**

```bash
git add social-network-analytics/queries/queries.sh
git commit -m "feat(social-network-analytics): add curl queries"
```

---

### Task 8: Java — pom.xml

**Files:**
- Create: `social-network-analytics/java/pom.xml`

**Step 1: Write pom.xml**

Copy from `fraud-detection/java/pom.xml`, change artifactId, mainClass, and finalName.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>com.arcadedb.examples</groupId>
  <artifactId>social-network-analytics</artifactId>
  <version>1.0-SNAPSHOT</version>
  <packaging>jar</packaging>

  <properties>
    <maven.compiler.source>21</maven.compiler.source>
    <maven.compiler.target>21</maven.compiler.target>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <arcadedb.version>26.3.1</arcadedb.version>
  </properties>

  <repositories>
    <repository>
      <name>Central Portal Snapshots</name>
      <id>central-portal-snapshots</id>
      <url>https://central.sonatype.com/repository/maven-snapshots/</url>
      <releases>
        <enabled>false</enabled>
      </releases>
      <snapshots>
        <enabled>true</enabled>
      </snapshots>
    </repository>
  </repositories>

  <dependencies>
    <dependency>
      <groupId>com.arcadedb</groupId>
      <artifactId>arcadedb-network</artifactId>
      <version>${arcadedb.version}</version>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-assembly-plugin</artifactId>
        <version>3.8.0</version>
        <configuration>
          <archive>
            <manifest>
              <mainClass>com.arcadedb.examples.SocialNetworkAnalytics</mainClass>
            </manifest>
          </archive>
          <descriptorRefs>
            <descriptorRef>jar-with-dependencies</descriptorRef>
          </descriptorRefs>
          <finalName>social-network-analytics</finalName>
          <appendAssemblyId>false</appendAssemblyId>
        </configuration>
        <executions>
          <execution>
            <id>make-assembly</id>
            <phase>package</phase>
            <goals>
              <goal>single</goal>
            </goals>
          </execution>
        </executions>
      </plugin>
    </plugins>
  </build>
</project>
```

**Step 2: Commit**

```bash
git add social-network-analytics/java/pom.xml
git commit -m "feat(social-network-analytics): add Maven pom.xml"
```

---

### Task 9: Java — SocialNetworkAnalytics.java

**Files:**
- Create: `social-network-analytics/java/src/main/java/com/arcadedb/examples/SocialNetworkAnalytics.java`

**Step 1: Write the Java program**

Five query methods matching the five shell queries. Uses `tryRun()`/`printHeader()` pattern. Uses `db.query("opencypher", ...)` for graph traversals. For InfluenceScores, uses `db.command("sql", "REFRESH MATERIALIZED VIEW InfluenceScores")` before querying.

```java
package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;

public class SocialNetworkAnalytics {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME  = "SocialNetwork";
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
      tryRun(() -> runQuery1TrendingDashboard(db), "Query 1");
      tryRun(() -> runQuery2EngagementTimeSeries(db), "Query 2");
      tryRun(() -> runQuery3InfluenceLeaderboard(db), "Query 3");
      tryRun(() -> runQuery4ViralSpreadChain(db), "Query 4");
      tryRun(() -> runQuery5CommunityOverlap(db), "Query 5");
    }
    System.out.println("\nAll queries complete.");
  }

  private static void tryRun(Runnable r, String name) {
    try {
      r.run();
    } catch (Exception e) {
      System.err.println("[" + name + " FAILED] " + e.getMessage());
    }
  }

  // Query 1: Trending Content Dashboard (Materialized View — PERIODIC)
  private static void runQuery1TrendingDashboard(RemoteDatabase db) {
    printHeader("Query 1: Trending Content Dashboard (Materialized View — PERIODIC)",
        "Read pre-computed trending scores from the TrendingPosts materialized view.");

    String sql =
        """
            SELECT postRid, totalLikes, totalShares, totalComments, score
            FROM TrendingPosts
            ORDER BY score DESC
            LIMIT 10""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-25s | likes: %-5s | shares: %-5s | comments: %-5s | score: %s%n",
            r.getProperty("postRid"),
            r.getProperty("totalLikes"),
            r.getProperty("totalShares"),
            r.getProperty("totalComments"),
            r.getProperty("score"));
      }
    }
  }

  // Query 2: Engagement Time-Series
  private static void runQuery2EngagementTimeSeries(RemoteDatabase db) {
    printHeader("Query 2: Engagement Time-Series",
        "Drill into the viral post's engagement growth over time.");

    String sql =
        """
            SELECT timestamp, likes, shares, comments
            FROM EngagementMetric
            WHERE postRid = 'ai-trends-2026'
            ORDER BY timestamp""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %s | likes: %-5s | shares: %-5s | comments: %s%n",
            r.getProperty("timestamp"),
            r.getProperty("likes"),
            r.getProperty("shares"),
            r.getProperty("comments"));
      }
    }
  }

  // Query 3: Influence Leaderboard (Materialized View — MANUAL)
  private static void runQuery3InfluenceLeaderboard(RemoteDatabase db) {
    printHeader("Query 3: Influence Leaderboard (Materialized View — MANUAL)",
        "Refresh and query the InfluenceScores view for top users by follower count.");

    // Manual refresh before querying
    db.command("sql", "REFRESH MATERIALIZED VIEW InfluenceScores");
    System.out.println("  InfluenceScores refreshed.");
    System.out.println();

    String sql =
        """
            SELECT userName, handle, followers
            FROM InfluenceScores
            ORDER BY followers DESC
            LIMIT 5""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-10s | @%-10s | followers: %s%n",
            r.getProperty("userName"),
            r.getProperty("handle"),
            r.getProperty("followers"));
      }
    }
  }

  // Query 4: Viral Spread Chain (OpenCypher — Graph Traversal)
  private static void runQuery4ViralSpreadChain(RemoteDatabase db) {
    printHeader("Query 4: Viral Spread Chain (OpenCypher — Graph Traversal)",
        "Trace how the AI Trends post spread: author -> sharers -> their followers.");

    String cypher =
        """
            MATCH (author:User)-[:CREATED]->(p:Post)<-[:SHARED]-(sharer:User)<-[:FOLLOWS]-(audience:User)
            WHERE p.title = 'AI Trends in 2026'
            RETURN author.name AS author, sharer.name AS sharer, collect(DISTINCT audience.name) AS reachedAudience""";

    try (ResultSet rs = db.query("opencypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  author: %-10s | sharer: %-10s | reached: %s%n",
            r.getProperty("author"),
            r.getProperty("sharer"),
            r.getProperty("reachedAudience"));
      }
    }
  }

  // Query 5: Community Overlap (OpenCypher — Graph Traversal)
  private static void runQuery5CommunityOverlap(RemoteDatabase db) {
    printHeader("Query 5: Community Overlap (OpenCypher — Graph Traversal)",
        "Find users in the same group who also follow each other.");

    String cypher =
        """
            MATCH (a:User)-[:MEMBER_OF]->(g:Group)<-[:MEMBER_OF]-(b:User)
            WHERE (a)-[:FOLLOWS]->(b) AND id(a) < id(b)
            RETURN g.name AS group, a.name AS user1, b.name AS user2
            ORDER BY g.name""";

    try (ResultSet rs = db.query("opencypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  group: %-15s | %s -> follows -> %s%n",
            r.getProperty("group"),
            r.getProperty("user1"),
            r.getProperty("user2"));
      }
    }
  }

  private static void printHeader(String title, String description) {
    System.out.println("\n" + "=".repeat(70));
    System.out.println("  " + title);
    System.out.println("  " + description);
    System.out.println("=".repeat(70));
  }
}
```

**Step 2: Verify it compiles**

```bash
cd social-network-analytics/java
mvn compile -q
```

Expected: BUILD SUCCESS

**Step 3: Commit**

```bash
git add social-network-analytics/java/src/
git commit -m "feat(social-network-analytics): add Java program"
```

---

### Task 10: Full Integration Test

**Step 1: Start ArcadeDB and run setup**

```bash
cd social-network-analytics
docker compose up -d
./setup.sh
```

**Step 2: Run curl queries**

```bash
./queries/queries.sh
```

Expected: All 5 queries produce meaningful results.

**Step 3: Build and run Java**

```bash
cd java
mvn package -q
java -jar target/social-network-analytics.jar
```

Expected: Same 5 queries produce matching results.

**Step 4: Fix any issues found, commit fixes**

**Step 5: Tear down**

```bash
cd ..
docker compose down
```

---

### Task 11: README

**Files:**
- Create: `social-network-analytics/README.md`

**Step 1: Write README**

Follow the pattern from `realtime-analytics/README.md`. Include: overview, prerequisites, quickstart (3 steps), schema tables, query patterns table, sample data summary, ArcadeDB version notes.

Key sections to include:
- Overview: materialized views + graph + time-series + polyglot querying
- Prerequisites: Docker, curl, jq, Java 21, Maven
- Quickstart: `docker compose up -d`, `./setup.sh`, `./queries/queries.sh` or Java
- Schema: vertex types, edge types, document type, materialized views (with refresh modes)
- Query patterns table: 5 rows with pattern name, language (SQL/OpenCypher), signal type
- Sample data: 8 users, 12 posts, 4 topics, 3 groups, ~36 engagement metrics
- Materialized views section explaining the 3 refresh modes demonstrated
- ArcadeDB version note: 26.3.1, `opencypher` and `cypher` are aliases

**Step 2: Commit**

```bash
git add social-network-analytics/README.md
git commit -m "feat(social-network-analytics): add README"
```

---

### Task 12: CI Workflow

**Files:**
- Create: `.github/workflows/social-network-analytics.yml`

**Step 1: Write the CI workflow**

Copy from `.github/workflows/realtime-analytics.yml`. Change 5 values:
1. `name: Social Network Analytics CI`
2. `paths:` → `social-network-analytics/**` and `.github/workflows/social-network-analytics.yml`
3. Cache key hash: `social-network-analytics/java/pom.xml`
4. `working-directory:` → `social-network-analytics` (and `social-network-analytics/java`)
5. JAR filename: `social-network-analytics.jar`

Remove the Grafana service — this use case doesn't use Grafana.

```yaml
name: Social Network Analytics CI

on:
  push:
    paths:
      - social-network-analytics/**
      - .github/workflows/social-network-analytics.yml
  pull_request:
    paths:
      - social-network-analytics/**
      - .github/workflows/social-network-analytics.yml

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      contents: read
    strategy:
      fail-fast: false
      matrix:
        runner: [curl, java]

    env:
      ARCADEDB_URL: http://localhost:2480
      ARCADEDB_USER: root
      ARCADEDB_PASS: arcadedb

    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          fetch-depth: 1

      - name: Set up Java
        if: matrix.runner == 'java'
        uses: actions/setup-java@be666c2fcd27ec809703dec50e508c2fdc7f6654 # v5.2.0
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: Cache Maven repository
        if: matrix.runner == 'java'
        uses: actions/cache@cdf6c1fa76f9f475f3d7449005a359c84ca0f306 # v5.0.3
        with:
          path: ~/.m2
          key: ${{ runner.os }}-m2-${{ hashFiles('social-network-analytics/java/pom.xml') }}
          restore-keys: ${{ runner.os }}-m2-

      - name: Start ArcadeDB
        working-directory: social-network-analytics
        run: docker compose up -d

      - name: Setup database
        working-directory: social-network-analytics
        run: ./setup.sh

      - name: Run curl queries
        if: matrix.runner == 'curl'
        working-directory: social-network-analytics
        run: ./queries/queries.sh

      - name: Build and run Java
        if: matrix.runner == 'java'
        working-directory: social-network-analytics/java
        run: |
          mvn package --no-transfer-progress
          java -jar target/social-network-analytics.jar

      - name: Teardown
        if: always()
        working-directory: social-network-analytics
        run: docker compose down
```

**Step 2: Commit**

```bash
git add .github/workflows/social-network-analytics.yml
git commit -m "ci: add social-network-analytics workflow"
```

---

### Task 13: Update Root README

**Files:**
- Modify: `README.md` (root)

**Step 1: Add the new use case to the table**

Add a row to the use cases table:

```markdown
| [social-network-analytics](./social-network-analytics/) | Social network analytics with materialized view dashboards | Materialized views, Graph traversal, Time-series, Polyglot (SQL + OpenCypher) |
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add social-network-analytics to root README"
```

---

### Task 14: Final Verification

**Step 1: Run the full flow one more time**

```bash
cd social-network-analytics
docker compose up -d
./setup.sh
./queries/queries.sh
cd java && mvn package -q && java -jar target/social-network-analytics.jar
cd ..
docker compose down
```

**Step 2: Verify all files are committed**

```bash
git status
```

Expected: clean working tree.
