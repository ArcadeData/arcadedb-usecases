# ArcadeDB Use Cases

A collection of self-contained projects demonstrating how to use [ArcadeDB](https://arcadedb.com).

Each use case lives in its own directory with a Docker Compose file, SQL schema/data files,
and runnable demos via both `curl` and a Java program.

## Use Cases

| Directory | Description | ArcadeDB features |
|-----------|-------------|-------------------|
| [recommendation-engine](./recommendation-engine/) | Intelligent product and content recommendations | Graph traversal, Vector similarity, Time-series |

## Structure

Each use case directory contains:
- `docker-compose.yml` — ArcadeDB instance (pinned version)
- `setup.sh` — creates the database and loads schema + data
- `sql/01-schema.sql` — vertex/edge type definitions
- `sql/02-data.sql` — sample data
- `queries/queries.sh` — all queries via `curl`
- `java/` — standalone Maven project running the same queries via `arcadedb-network`
- `README.md` — quickstart guide
