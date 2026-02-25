# CI Pipeline Design

**Date:** 2026-02-25
**Branch:** infra/add-workflows

## Overview

Add a GitHub Actions CI pipeline that verifies every use case works correctly across all implemented programming languages. The pipeline starts with the `recommendation-engine` use case and its two existing runners: `queries/queries.sh` (curl) and `java/`.

## Goals

- Every push and pull request that touches a use case directory is verified automatically
- Each language runner is tested in isolation — a Java failure does not mask a curl failure
- Adding a new language costs one matrix entry and two conditional steps
- Pass criterion is exit code 0 (queries run without crashing)

## Workflow File

`.github/workflows/recommendation-engine.yml`

## Triggers

```yaml
on:
  push:
    paths:
      - recommendation-engine/**
      - .github/workflows/recommendation-engine.yml
  pull_request:
    paths:
      - recommendation-engine/**
      - .github/workflows/recommendation-engine.yml
```

## Strategy: Matrix Job

One `test` job with `matrix: runner: [curl, java]`. Each entry runs on its own GitHub-hosted runner (fresh Ubuntu VM), so there are no port conflicts and no shared state between entries.

Future languages: add `python` or `node` to the matrix array plus a conditional `run:` step.

## Job Steps (each matrix entry)

| Step | Details |
|------|---------|
| Checkout | `actions/checkout@v4`, `fetch-depth: 1` |
| Set up Java | `actions/setup-java@v4`, temurin 17 — gated `if: matrix.runner == 'java'` |
| Maven cache | `actions/cache@v4` keyed on `pom.xml` hash — gated `if: matrix.runner == 'java'` |
| Start ArcadeDB | `docker compose up -d` from `recommendation-engine/` |
| Setup DB | `./setup.sh` — polls until ready, creates DB, loads schema + data |
| Run curl queries | `./queries/queries.sh` — gated `if: matrix.runner == 'curl'` |
| Build + run Java | `mvn package -q && java -jar target/recommendation-engine.jar` — gated `if: matrix.runner == 'java'` |
| Teardown | `docker compose down` — `if: always()` |

## Environment Variables

Passed to all steps via `env:` at job level:

```
ARCADEDB_URL=http://localhost:2480
ARCADEDB_USER=root
ARCADEDB_PASS=arcadedb
```

These match the defaults already used by `setup.sh` and `queries/queries.sh` — no changes to existing scripts needed.

## Pass Criteria

Exit code 0. Each query must complete without error. No output content validation.

## Edge Cases

**ArcadeDB not ready:** `setup.sh` has a polling loop (`until curl -sf ... /api/v1/ready`). If ArcadeDB never becomes healthy, the script exits non-zero and the job fails at the setup step. Teardown still runs via `if: always()`.

**`jq` and `curl`:** Both are present on `ubuntu-latest` — no install step needed.

**Maven dependencies:** `arcadedb-network` is on Maven Central. No custom registry needed. The `~/.m2` cache avoids re-downloading on repeat runs.

**Port conflicts:** Not possible — each matrix entry runs on a fresh, isolated VM.

## Extensibility

To add Python once `recommendation-engine/python/` exists:

```yaml
# 1. Extend the matrix
runner: [curl, java, python]

# 2. Add setup step (gated)
- uses: actions/setup-python@v5
  if: matrix.runner == 'python'
  with:
    python-version: '3.12'

# 3. Add run step (gated)
- name: Run Python
  if: matrix.runner == 'python'
  working-directory: recommendation-engine/python
  run: python main.py
```

Node.js follows the same pattern with `actions/setup-node@v4`.

## Success Criteria

- Pushing a change to `recommendation-engine/` triggers the workflow
- Both matrix entries (`curl`, `java`) complete with exit code 0
- A broken query (e.g., wrong ArcadeDB syntax) causes the relevant entry to fail while the other passes
