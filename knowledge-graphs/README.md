# Knowledge Graphs

Demonstrates ArcadeDB's multi-model capabilities using an academic research
knowledge graph that unifies four signal types in a single database:

- **Graph traversal** — co-authorship network and citation graph multi-hop queries
- **Vector similarity** — semantic paper search using embeddings
- **Full-text search** — keyword search across paper abstracts
- **Time-series** — trending papers by cumulative citation activity

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

This creates the `KnowledgeGraph` database, applies the schema, and inserts sample data.

### 3a. Run queries via curl

```bash
./queries/queries.sh
```

### 3b. Run queries via Java

```bash
cd java
mvn package -q
java -jar target/knowledge-graph.jar
```

## Schema

| Type | Kind | Key properties |
|------|------|----------------|
| `Researcher` | Vertex | `id`, `name`, `embedding` |
| `Paper` | Vertex | `id`, `title`, `abstract`, `year`, `embedding` |
| `Topic` | Vertex | `id`, `name`, `embedding` |
| `Institution` | Vertex | `id`, `name` |
| `CO_AUTHORED` | Edge | Researcher → Paper |
| `CITES` | Edge | Paper → Paper |
| `COVERS` | Edge | Paper → Topic |
| `AFFILIATED_WITH` | Edge | Researcher → Institution |
| `PaperActivity` | Document | `paperId`, `citationCount`, `ts` |

## Query Patterns

| # | Pattern | Language | Pillar |
|---|---------|----------|--------|
| 1 | Co-authorship Network | Cypher | Graph |
| 2 | Semantic Paper Search | SQL + vectorNeighbors | Vector |
| 3 | Full-Text Abstract Search | SQL + SEARCH_INDEX | Full-text |
| 4 | Trending Papers | SQL | Time-series |
| 5 | GraphRAG Hybrid | SQL + MATCH | Graph + Vector |

## Sample Data

- 5 researchers, 4 institutions, 6 topics, 10 papers
- 11 CO_AUTHORED edges, 10 CITES edges, 15 COVERS edges, 5 AFFILIATED_WITH edges
- 10 PaperActivity records (citation events for time-series queries)
- 4-dimensional embeddings throughout

## ArcadeDB Version Notes

This use case targets ArcadeDB **26.2.1**. Vector similarity uses
`vectorNeighbors('IndexName[property]', vector, k)` with an `LSM_VECTOR` index.
Full-text search uses `SEARCH_INDEX('Paper[abstract]', 'query')` against a `FULL_TEXT` index on
`Paper(abstract)`.

## Reference

[ArcadeDB Knowledge Graphs use case](https://arcadedb.com/knowledge-graphs.html)
