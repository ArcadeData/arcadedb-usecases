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
| `Paper` | Vertex | `id`, `title`, `abstract`, `year`, `topics` (list of topic names, for facets), `embedding` |
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
| 6 | Faceted Paper Search | SQL + SEARCH_INDEX + FACETS | Full-text + Facets |

### Faceted search (Query 6)

> **Faceted search needs ArcadeDB 26.12.1.** Until that release is out, `docker-compose.yml` and
> `java/pom.xml` point to `26.12.1-SNAPSHOT` (the Docker Hub tag and Maven Central snapshots).

Query 6 runs a full-text search and returns, in the same response, how the matches split by topic, by
year and by era. The counts cover every match, not only the `LIMIT` page:

```sql
SELECT id, title, year FROM Paper
WHERE SEARCH_INDEX('Paper[abstract]', 'graph') = true
FACETS
  topics TERMS TOP 10,
  year TERMS ORDER BY VALUE ASC,
  era: year RANGES ([*, 2023) AS 'before 2023', [2023, *) AS '2023 and later')
LIMIT 5
```

Facets read a `COLUMNAR` index per property (`CREATE INDEX ON Paper (topics BY ITEM) COLUMNAR`).
The second part of the query shows disjunctive facets: with `FILTER` on a facet, the rows pass every
filter, while each facet counts as if its own filter were not applied, so the other values keep
their counts. Over HTTP the facets come back in a `facets` object next to `result`; in Java,
`ResultSet.getFacets()` returns them.

## Sample Data

- 5 researchers, 4 institutions, 6 topics, 10 papers
- 11 CO_AUTHORED edges, 10 CITES edges, 15 COVERS edges, 5 AFFILIATED_WITH edges
- 10 PaperActivity records (citation events for time-series queries)
- 4-dimensional embeddings throughout

## ArcadeDB Version Notes

This use case targets ArcadeDB **26.12.1** (currently `26.12.1-SNAPSHOT`). Vector similarity uses
`vectorNeighbors('IndexName[property]', vector, k)` with an `LSM_VECTOR` index.
Full-text search uses `SEARCH_INDEX('Paper[abstract]', 'query')` against a `FULL_TEXT` index on
`Paper(abstract)`.

## Reference

[ArcadeDB Knowledge Graphs use case](https://arcadedb.com/knowledge-graphs.html)
