# Knowledge Graphs Use Case — Design

**Date:** 2026-02-25
**Branch:** feat/knowledge-graphs
**ArcadeDB version:** 26.2.1

## Overview

Implement the [ArcadeDB Knowledge Graphs](https://arcadedb.com/knowledge-graphs.html) use case as the second entry in the `arcadedb-usecases` repository. The use case demonstrates ArcadeDB's ability to unify four signal types — graph traversal, vector similarity, full-text search, and time-series — in a single database, applied to an academic research knowledge graph.

## Repository Structure

Each use case lives in its own top-level directory and is fully self-contained (no shared parent POM or shared lib).

```
arcadedb-usecases/
├── README.md
├── recommendation-engine/
└── knowledge-graphs/
    ├── README.md
    ├── docker-compose.yml
    ├── setup.sh
    ├── sql/
    │   ├── 01-schema.sql
    │   └── 02-data.sql
    ├── queries/
    │   └── queries.sh
    └── java/
        ├── pom.xml
        └── src/main/java/com/arcadedb/examples/
            └── KnowledgeGraph.java
```

## Docker Compose

- Single service: `arcadedata/arcadedb:26.2.1`
- HTTP API port exposed: `2480`
- Root credentials passed as environment variables (`ARCADEDB_SERVER_ROOTPASSWORD`)
- No setup container — the README documents a one-time `setup.sh` invocation to create the database and apply the SQL files

## Schema (`sql/01-schema.sql`)

Four vertex types, four edge types, one document type:

**Vertices:**
- `Researcher` — `id` (STRING, unique), `name` (STRING), `embedding` (LIST)
- `Paper` — `id` (STRING, unique), `title` (STRING), `abstract` (STRING), `year` (INTEGER), `embedding` (LIST)
- `Topic` — `id` (STRING, unique), `name` (STRING), `embedding` (LIST)
- `Institution` — `id` (STRING, unique), `name` (STRING)

**Edges:**
- `CO_AUTHORED` — Researcher → Paper
- `CITES` — Paper → Paper
- `COVERS` — Paper → Topic
- `AFFILIATED_WITH` — Researcher → Institution

**Document type (time-series):**
- `PaperActivity` — `paperId` (STRING), `citationCount` (LONG), `ts` (DATETIME)

**Indexes:**
- `Paper(embedding)` — LSM_VECTOR, 4 dimensions, COSINE similarity (semantic search)
- `Topic(embedding)` — LSM_VECTOR, 4 dimensions, COSINE similarity (GraphRAG expansion)
- `Paper(abstract)` — FULL_TEXT (keyword search in abstracts)
- `Paper(id)` — UNIQUE
- `Researcher(id)` — UNIQUE
- `Topic(id)` — UNIQUE
- `Institution(id)` — UNIQUE

## Sample Data (`sql/02-data.sql`)

Approximately:
- 5 researchers with 4-dimensional embedding vectors
- 4 institutions
- 6 topics with 4-dimensional embeddings
- 10 papers with 4-dimensional embeddings and short abstracts
- ~35 edges: `CO_AUTHORED`, `CITES`, `COVERS`, `AFFILIATED_WITH`
- ~20 `PaperActivity` records with varying timestamps to enable time-series queries

Embeddings use small fixed-dimension float arrays (4 dimensions) — sufficient to demonstrate `vectorNeighbors()` without bloating the file.

## curl Queries (`queries/queries.sh`)

Five labeled sections, one per query pattern, each POSTing to `http://localhost:2480/api/v1/query/KnowledgeGraph`:

1. **Co-authorship Network** — Cypher `MATCH` traversal, finds researchers connected to `r1` within 2 co-authorship hops
2. **Semantic Paper Search** — SQL `vectorNeighbors()`, finds papers semantically similar to a query embedding
3. **Full-Text Abstract Search** — SQL full-text index query, finds papers whose abstract contains specific keywords
4. **Trending Topics** — SQL time-series aggregation, ranks topics by cumulative recent citation activity from `PaperActivity`
5. **GraphRAG Hybrid** — SQL combining vector search (seed papers) with citation graph expansion (`CITES`) to discover connected topics — all in one query

All queries use hardcoded values matching `02-data.sql` so the script works out-of-the-box after setup.

## Java Program (`java/`)

- **Build tool:** Maven (standalone `pom.xml`, no parent)
- **Dependency:** `com.arcadedb:arcadedb-network:26.2.1`
- **Output:** executable fat JAR via `maven-jar-plugin` (`mvn package` → `java -jar target/knowledge-graph.jar`)
- **Entry point:** single `KnowledgeGraph.java` with a `main` method that:
  1. Opens a `RemoteDatabase` connection to `localhost:2480`
  2. Runs all 5 queries sequentially
  3. Prints a header and formatted results for each query to stdout
  4. Closes the connection

Same `tryRun()` / `printHeader()` helper pattern as `RecommendationEngine.java`.

## Query Language Mapping

| # | Pattern | Language |
|---|---------|----------|
| 1 | Co-authorship Network | Cypher |
| 2 | Semantic Paper Search | SQL |
| 3 | Full-Text Abstract Search | SQL |
| 4 | Trending Topics | SQL |
| 5 | GraphRAG Hybrid | SQL |

## ArcadeDB Pillar Coverage

| Pillar | Queries |
|--------|---------|
| Graph traversal | Q1, Q5 |
| Vector similarity | Q2, Q5 |
| Full-text search | Q3 |
| Time-series aggregation | Q4 |

## Success Criteria

- `docker compose up` starts ArcadeDB successfully
- `setup.sh` applies SQL files cleanly via curl with no errors
- `queries.sh` runs all 5 queries and returns non-empty result sets
- `mvn package && java -jar target/knowledge-graph.jar` runs all 5 queries and prints results to stdout
