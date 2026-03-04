# CLAUDE.md — ArcadeDB Use Cases

## Project Overview

A collection of self-contained projects demonstrating [ArcadeDB](https://arcadedb.com) multi-model database capabilities. Each use case lives in its own top-level directory with no shared dependencies — any directory can be copied out and used independently.

**Repository:** `arcadedata/arcadedb-usecases`

## Use Cases

| Directory | Database Name | ArcadeDB Version | Java | Connectivity |
|-----------|--------------|------------------|------|-------------|
| `recommendation-engine/` | `RecommendationEngine` | 26.3.1 | 21 | HTTP API (`arcadedb-network`) |
| `knowledge-graphs/` | `KnowledgeGraph` | 26.3.1 | 21 | HTTP API (`arcadedb-network`) |
| `graph-rag/` | `GraphRAG` | 26.3.1 | 21 | Bolt (`neo4j-java-driver`) + LangChain4j |
| `fraud-detection/` | `FraudDetection` | 26.3.1 | 21 | HTTP API (`arcadedb-network`) |

## Directory Structure (per use case)

Every use case follows this exact layout:
```
<use-case>/
├── docker-compose.yml          # Single arcadedb service, port 2480 (+2424 for Bolt)
├── setup.sh                    # Waits for ArcadeDB, creates DB, applies sql/ files
├── sql/
│   ├── 01-schema.sql           # One SQL statement per line (setup.sh strips trailing semicolons)
│   └── 02-data.sql             # INSERTs + CREATE EDGE statements, one per line
├── queries/
│   └── queries.sh              # Labeled query sections using query() helper
├── java/
│   ├── pom.xml                 # Standalone Maven project, maven-assembly-plugin fat JAR
│   └── src/main/java/com/arcadedb/examples/<ClassName>.java
└── README.md
```

`graph-rag/` additionally has a `langchain4j/` sibling module with its own `pom.xml`.

## Critical Conventions

### SQL Files
- **One statement per line** — `setup.sh` reads line-by-line and sends each to the HTTP API
- Trailing semicolons are stripped by `setup.sh` (include for readability but they're optional)
- Blank lines and `-- comment` lines are skipped
- Comments must start with `--` at the beginning of the line (optionally preceded by whitespace)

### setup.sh Pattern
- Uses env vars: `ARCADEDB_URL` (default `http://localhost:2480`), `ARCADEDB_USER` (default `root`), `ARCADEDB_PASS` (default `arcadedb`)
- Polls `/api/v1/ready` until ArcadeDB is up
- Creates database via `POST /api/v1/server` with `{"command": "create database <DB_NAME>"}`
- `send_sql()` helper uses `jq` to JSON-encode statements before POSTing to `/api/v1/command/<DB>`
- `apply_file()` reads SQL files line by line

### queries.sh Pattern
- Same env vars as setup.sh
- `query()` helper: takes `(language, command)`, POSTs to `/api/v1/query/<DB>`, pipes through `jq '.result'`
- Five labeled sections with echo headers, each calling `query "sql"` or `query "cypher"`

### Java Pattern
- Package: `com.arcadedb.examples`
- Config from env vars: `ARCADEDB_HOST`, `ARCADEDB_PORT` (or `ARCADEDB_BOLT_PORT`), `ARCADEDB_USER`, `ARCADEDB_PASS`
- Fat JAR via `maven-assembly-plugin` with `appendAssemblyId=false`
- `tryRun(Runnable, String)` wrapper for graceful per-query error handling
- `printHeader(String title, String description)` for formatted output
- Maven compiler target: Java 21

### Docker Compose
- Root password: `JAVA_OPTS: "-Darcadedb.server.rootPassword=arcadedb"`
  (not `ARCADEDB_SERVER_ROOTPASSWORD` — the env var doesn't work in 26.3.1)
- Healthcheck: `curl -sf http://localhost:2480/api/v1/ready`, interval 5s, retries 20
- graph-rag additionally exposes port 7687 for Bolt (ArcadeDB defaults to 7687, not 2424)

## ArcadeDB API Quirks (Discovered During Implementation)

- `vectorDistance()` does not exist in 26.3.1; use `vectorNeighbors('TypeName[property]', vector, k)` with an `LSM_VECTOR` index
- Vector indexes require the full index name format: `TypeName[propertyName]`
- `LET $var = (SELECT ... GROUP BY ...)` syntax is not supported
- `SEARCH_INDEX()` not supported in WHERE clauses; use `SEARCH_CLASS('query')` for full-text
- Cypher doesn't resolve parent type labels to subtypes (e.g., `:Entity` won't match `Person`)
- ArcadeDB Bolt protocol implements protocol v4; Neo4j driver 5.x fails handshake — use `neo4j-java-driver:4.4.12`
- Edges require vertex endpoints — use VERTEX TYPE (not DOCUMENT TYPE) for types that participate in edges
- `Neo4jEmbeddingStore` from LangChain4j doesn't work directly (uses `SHOW VECTOR INDEX` DDL); use direct Neo4j driver + `CosineSimilarity` instead

## CI Workflows

Located in `.github/workflows/`, one per use case. All follow the same matrix pattern:

```yaml
matrix:
  runner: [curl, java]
```

Each matrix entry:
1. Checks out code
2. Sets up Java 21 (temurin) — gated on `matrix.runner == 'java'`
3. Caches `~/.m2` — gated on `matrix.runner == 'java'`
4. `docker compose up -d`
5. `./setup.sh`
6. Runs curl queries OR builds/runs Java fat JAR
7. `docker compose down` with `if: always()`

Action SHAs are pinned. Use `--no-transfer-progress` for Maven in CI.

## Adding a New Use Case

1. Create directory matching the layout above
2. Write `docker-compose.yml` (copy from existing, adjust version if needed)
3. Write `setup.sh` (copy from existing, change `DB_NAME`)
4. Write `sql/01-schema.sql` and `sql/02-data.sql` (one statement per line)
5. Write `queries/queries.sh` (copy `query()` helper, change `DB` name)
6. Write Java program following the `tryRun()`/`printHeader()` pattern
7. Write `README.md` following existing format
8. Create `.github/workflows/<use-case>.yml` (copy existing, change 5 values: name, paths, cache key, working-directory, JAR filename)
9. Update root `README.md` use cases table
10. Write design doc and implementation plan in `docs/plans/`

## Git & PR Conventions

- Branch naming: `feat/<use-case>` for features, `infra/` for infrastructure
- Commit style: `feat(<scope>):`, `fix(<scope>):`, `ci:`, `docs:`, `chore:`
- Each use case is developed on its own feature branch and merged via PR
- Dependabot configured for Docker and Maven dependency updates
- Mergify configured for automated merges
- Pre-commit hooks are configured (`.pre-commit-config.yaml`)

## Plans & Documentation

Design documents and implementation plans live in `docs/plans/` with date-prefixed filenames:
- `*-design.md` — architecture, schema, query patterns, success criteria
- `*-ci.md` — CI workflow specifications
- Implementation plans (`*.md` without suffix) — step-by-step task lists

## Key File Paths

- Root README: `README.md`
- CI workflows: `.github/workflows/<use-case>.yml`
- Design docs: `docs/plans/`
- Java source: `<use-case>/java/src/main/java/com/arcadedb/examples/`
- Schema: `<use-case>/sql/01-schema.sql`
- Data: `<use-case>/sql/02-data.sql`
