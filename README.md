# ArcadeDB Use Cases

A collection of self-contained projects demonstrating how to use [ArcadeDB](https://arcadedb.com).

Each use case lives in its own directory with a Docker Compose file, SQL schema/data files,
and runnable demos via both `curl` and a Java program.

## Use Cases

| Directory | Description | ArcadeDB features |
|-----------|-------------|-------------------|
| [recommendation-engine](./recommendation-engine/) | Intelligent product and content recommendations | Graph traversal, Vector similarity, Time-series |
| [knowledge-graphs](./knowledge-graphs/) | Academic research knowledge graph with co-authorship and citation networks | Graph traversal, Vector similarity, Full-text search, Time-series |
| [graph-rag](./graph-rag/) | Graph RAG system combining knowledge graphs with vector search for retrieval-augmented generation | Graph traversal, Vector similarity, Full-text indexing, Neo4j Bolt, LangChain4j |
| [fraud-detection](./fraud-detection/) | Fraud detection system unifying graph, vector, and time-series signals | Graph traversal, Vector similarity, Time-series, Cypher |
| [realtime-analytics](./realtime-analytics/) | Unified IoT and service monitoring platform | Time-series, Graph traversal, Cypher |

## Structure

Each use case directory contains:
- `docker-compose.yml` — ArcadeDB instance (pinned version)
- `setup.sh` — creates the database and loads schema + data
- `sql/01-schema.sql` — vertex/edge type definitions
- `sql/02-data.sql` — sample data
- `queries/queries.sh` — all queries via `curl`
- `java/` — standalone Maven project running the same queries via Java
- `README.md` — quickstart guide
