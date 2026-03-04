# Recommendation Engine Use Case — Design

**Date:** 2026-02-25
**Branch:** feat/recommendation-engine
**ArcadeDB version:** 26.3.1

## Overview

Implement the [ArcadeDB Recommendation Engine](https://arcadedb.com/recommendation-engine.html) use case as the first entry in the `arcadedb-usecases` repository. The use case demonstrates ArcadeDB's ability to unify three signal types — graph traversal, vector similarity, and time-series — in a single database.

## Repository Structure

Each use case lives in its own top-level directory and is fully self-contained (no shared parent POM or shared lib). This maximises portability: any single usecase directory can be copied out and used independently.

```
arcadedb-usecases/
├── README.md
└── recommendation-engine/
    ├── README.md
    ├── docker-compose.yml
    ├── sql/
    │   ├── 01-schema.sql
    │   └── 02-data.sql
    ├── queries/
    │   └── queries.sh
    └── java/
        ├── pom.xml
        └── src/main/java/
            └── RecommendationEngine.java
```

## Docker Compose

- Single service: `arcadedata/arcadedb:26.3.1`
- HTTP API port exposed: `2480`
- Root credentials passed as environment variables (`ARCADEDB_SERVER_ROOTPASSWORD`)
- No setup container — the README documents a one-time `curl` command to create the database and apply the SQL files

## Schema (`sql/01-schema.sql`)

Three vertex types and three edge types:

**Vertices:**
- `User` — `id` (STRING), `embedding` (LIST)
- `Product` — `name` (STRING), `category` (STRING), `price` (FLOAT), `inStock` (BOOLEAN), `embedding` (LIST)
- `Show` — `title` (STRING), `genre` (STRING), `embedding` (LIST)

**Edges:**
- `PURCHASED` — User → Product
- `WATCHED` — User → Show
- `INTERACTED` — User → Product

## Sample Data (`sql/02-data.sql`)

Approximately:
- 5 users with 4-dimensional embedding vectors
- 10 products across multiple categories with 4-dimensional embeddings
- 5 shows with 4-dimensional embeddings
- ~30 edges creating realistic overlap (so collaborative filtering returns neighbours, vector distances vary meaningfully)

Embeddings use small fixed-dimension float arrays (4 dimensions) — sufficient to demonstrate `vectorDistance()` without bloating the file.

## curl Queries (`queries/queries.sh`)

Five labeled sections, one per query pattern, each POSTing to `http://localhost:2480/api/v1/query/RecommendationEngine`:

1. **Collaborative Filtering** — Cypher `MATCH` traversal, finds products bought by users with overlapping purchase history
2. **Vector Similarity Search** — SQL `vectorDistance()`, finds semantically similar products
3. **Trending Detection** — SQL time-series `rate()`, identifies products with accelerating engagement
4. **Multi-Model Hybrid (Streaming)** — combines graph traversal + vector similarity + time-series for show recommendations
5. **E-Commerce Personalized Category Page** — blends session vector with trending score

All queries use hardcoded values matching `02-data.sql` (known user IDs, sample embedding vectors) so the script works out-of-the-box after setup.

## Java Program (`java/`)

- **Build tool:** Maven (standalone `pom.xml`, no parent)
- **Dependency:** `com.arcadedb:arcadedb-network:26.3.1`
- **Output:** executable fat JAR via `maven-jar-plugin` (`mvn package` → `java -jar target/recommendation-engine.jar`)
- **Entry point:** single `RecommendationEngine.java` with a `main` method that:
  1. Opens a `RemoteDatabase` connection to `localhost:2480`
  2. Runs all 5 queries sequentially
  3. Prints a header and JSON results for each query to stdout
  4. Closes the connection

## Query Language Mapping

| # | Pattern | Language |
|---|---------|----------|
| 1 | Collaborative Filtering | Cypher |
| 2 | Vector Similarity | SQL |
| 3 | Trending Detection | SQL |
| 4 | Streaming Hybrid | SQL (with LET) |
| 5 | E-Commerce Category Page | Cypher + SQL |

## Success Criteria

- `docker compose up` starts ArcadeDB successfully
- SQL files apply cleanly via `curl` with no errors
- `queries.sh` runs all 5 queries and returns non-empty result sets
- `mvn package && java -jar ...` runs all 5 queries and prints results to stdout
