# Knowledge Graphs CI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create `.github/workflows/knowledge-graphs.yml` — a matrix CI workflow that verifies both the `curl` and `java` runners for the knowledge-graphs use case on every push and pull request.

**Architecture:** One `test` job with `matrix: runner: [curl, java]`. Each entry starts ArcadeDB via `docker compose up -d`, runs `./setup.sh` to create the database and load schema + data, runs the language-specific command, then tears down with `if: always()`. This is an exact port of `.github/workflows/recommendation-engine.yml` with five values changed: workflow name, path filters, Maven cache key, working directories, and the JAR filename.

**Tech Stack:** GitHub Actions, `actions/checkout@v4`, `actions/setup-java@v4` (temurin 21), `actions/cache@v4`, Docker Compose, Maven 3.x, Java 21, bash/curl/jq (pre-installed on `ubuntu-latest`)

---

### Reference: what changes from recommendation-engine.yml

Before writing, understand the five differences:

| Field | recommendation-engine.yml | knowledge-graphs.yml |
|---|---|---|
| `name` | `Recommendation Engine CI` | `Knowledge Graph CI` |
| `paths` trigger | `recommendation-engine/**` | `knowledge-graphs/**` |
| workflow path trigger | `.github/workflows/recommendation-engine.yml` | `.github/workflows/knowledge-graphs.yml` |
| Maven cache key | `hashFiles('recommendation-engine/java/pom.xml')` | `hashFiles('knowledge-graphs/java/pom.xml')` |
| `working-directory` (all steps) | `recommendation-engine` / `recommendation-engine/java` | `knowledge-graphs` / `knowledge-graphs/java` |
| JAR filename | `target/recommendation-engine.jar` | `target/knowledge-graph.jar` |

Everything else — action SHAs, Java version (21), `fail-fast: false`, `timeout-minutes: 15`, env vars, `--no-transfer-progress` flag — is identical.

---

### Task 1: Create the workflow file

**Files:**
- Create: `.github/workflows/knowledge-graphs.yml`
- Reference: `.github/workflows/recommendation-engine.yml` (do not modify)

**Step 1: Write the file**

```yaml
name: Knowledge Graph CI

on:
  push:
    paths:
      - knowledge-graphs/**
      - .github/workflows/knowledge-graphs.yml
  pull_request:
    paths:
      - knowledge-graphs/**
      - .github/workflows/knowledge-graphs.yml

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
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
        with:
          fetch-depth: 1

      - name: Set up Java
        if: matrix.runner == 'java'
        uses: actions/setup-java@c5195efecf7bdfc987ee8bae7a71cb8b11521c00 # v4.7.1
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: Cache Maven repository
        if: matrix.runner == 'java'
        uses: actions/cache@5a3ec84eff668545956fd18022155c47e93e2684 # v4.2.3
        with:
          path: ~/.m2
          key: ${{ runner.os }}-m2-${{ hashFiles('knowledge-graphs/java/pom.xml') }}
          restore-keys: ${{ runner.os }}-m2-

      - name: Start ArcadeDB
        working-directory: knowledge-graphs
        run: docker compose up -d

      - name: Setup database
        working-directory: knowledge-graphs
        run: ./setup.sh

      - name: Run curl queries
        if: matrix.runner == 'curl'
        working-directory: knowledge-graphs
        run: ./queries/queries.sh

      - name: Build and run Java
        if: matrix.runner == 'java'
        working-directory: knowledge-graphs/java
        run: |
          mvn package --no-transfer-progress
          java -jar target/knowledge-graph.jar

      - name: Teardown
        if: always()
        working-directory: knowledge-graphs
        run: docker compose down
```

**Step 2: Validate YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/knowledge-graphs.yml'))" && echo "YAML valid"
```

Expected: `YAML valid`

**Step 3: Diff against recommendation-engine.yml to confirm only the expected 5 fields changed**

```bash
diff .github/workflows/recommendation-engine.yml .github/workflows/knowledge-graphs.yml
```

Expected diff (only these lines differ — no other changes):
```
< name: Recommendation Engine CI
> name: Knowledge Graph CI
---
<       - recommendation-engine/**
<       - .github/workflows/recommendation-engine.yml
>       - knowledge-graphs/**
>       - .github/workflows/knowledge-graphs.yml
---
<           key: ${{ runner.os }}-m2-${{ hashFiles('recommendation-engine/java/pom.xml') }}
>           key: ${{ runner.os }}-m2-${{ hashFiles('knowledge-graphs/java/pom.xml') }}
---
<         working-directory: recommendation-engine
>         working-directory: knowledge-graphs
(repeated for each working-directory occurrence)
---
<           java -jar target/recommendation-engine.jar
>           java -jar target/knowledge-graph.jar
```

If any other lines differ, investigate before committing.

**Step 4: Commit**

```bash
git add .github/workflows/knowledge-graphs.yml
git commit -m "ci: add knowledge-graphs workflow (curl + java matrix)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Verify the workflow triggers

**Step 1: Push the branch and check GitHub Actions**

```bash
git push -u origin feat/knowledge-graphs
```

Open: `https://github.com/arcadedata/arcadedb-usecases/actions`

Expected: a `Knowledge Graph CI` run appears with two jobs — `test (curl)` and `test (java)`.

**Step 2: Confirm both jobs pass**

Both `test (curl)` and `test (java)` should show green checkmarks. If either fails, check the step-level logs:

- **Start ArcadeDB fails:** confirm `docker compose up -d` runs from `knowledge-graphs/` — check `working-directory`
- **Setup database fails:** `setup.sh` polls with `until curl ... /api/v1/ready` — if ArcadeDB is slow, it will retry every 2s; check the log for repeated "Waiting" messages
- **curl queries fail:** Q3 uses `SEARCH_INDEX` (not `SEARCH_CLASS`) and Q5 uses hardcoded IDs `['p2', 'p8', 'p4']` — these were verified locally in the smoke test
- **Java build fails:** confirm Maven resolves `arcadedb-network:26.3.1` from Maven Central; check `~/.m2` cache step
- **Java run fails:** the fat JAR is at `target/knowledge-graph.jar` — confirm `finalName` in `knowledge-graphs/java/pom.xml` is `knowledge-graph`

**Step 3: No further commit needed if both pass**
