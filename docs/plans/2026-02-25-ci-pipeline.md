# CI Pipeline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create `.github/workflows/recommendation-engine.yml` — a matrix CI workflow that verifies both the `curl` and `java` runners for the recommendation-engine use case on every push and pull request.

**Architecture:** One `test` job with `matrix: runner: [curl, java]`. Each entry is self-contained: it starts ArcadeDB via `docker compose up -d`, runs `./setup.sh` to load schema and data, runs the language-specific command, then tears down with `if: always()`. Pass criterion is exit code 0.

**Tech Stack:** GitHub Actions, `actions/checkout@v4`, `actions/setup-java@v4` (temurin 17), `actions/cache@v4`, Docker Compose, Maven 3.x, Java 17, bash/curl/jq (pre-installed on `ubuntu-latest`)

---

### Task 1: Create the workflow file

**Files:**
- Create: `.github/workflows/recommendation-engine.yml`

**Step 1: Write the file**

```yaml
name: Recommendation Engine CI

on:
  push:
    paths:
      - recommendation-engine/**
      - .github/workflows/recommendation-engine.yml
  pull_request:
    paths:
      - recommendation-engine/**
      - .github/workflows/recommendation-engine.yml

jobs:
  test:
    runs-on: ubuntu-latest
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
          java-version: '17'
          distribution: 'temurin'

      - name: Cache Maven repository
        if: matrix.runner == 'java'
        uses: actions/cache@5a3ec84eff668545956fd18022155c47e93e2684 # v4.2.3
        with:
          path: ~/.m2
          key: ${{ runner.os }}-m2-${{ hashFiles('recommendation-engine/java/pom.xml') }}
          restore-keys: ${{ runner.os }}-m2-

      - name: Start ArcadeDB
        working-directory: recommendation-engine
        run: docker compose up -d

      - name: Setup database
        working-directory: recommendation-engine
        run: ./setup.sh

      - name: Run curl queries
        if: matrix.runner == 'curl'
        working-directory: recommendation-engine
        run: ./queries/queries.sh

      - name: Build and run Java
        if: matrix.runner == 'java'
        working-directory: recommendation-engine/java
        run: |
          mvn package -q
          java -jar target/recommendation-engine.jar

      - name: Teardown
        if: always()
        working-directory: recommendation-engine
        run: docker compose down
```

**Step 2: Validate YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/recommendation-engine.yml'))" && echo "YAML valid"
```

Expected: `YAML valid`

**Step 3: Commit**

```bash
git add .github/workflows/recommendation-engine.yml
git commit -m "ci: add recommendation-engine workflow (curl + java matrix)"
```

---

### Task 2: Verify the workflow triggers

**Step 1: Push the branch and check GitHub Actions**

```bash
git push origin infra/add-workflows
```

Open: `https://github.com/<org>/arcadedb-usecases/actions`

Expected: a `Recommendation Engine CI` run appears with two jobs — `test (curl)` and `test (java)`.

**Step 2: Confirm both jobs pass**

Both `test (curl)` and `test (java)` should show green checkmarks. If either fails, check the step-level logs:

- **Start ArcadeDB fails:** confirm `docker compose up -d` runs from the `recommendation-engine/` directory — check `working-directory`
- **Setup database fails:** `setup.sh` may be timing out waiting for ArcadeDB; check if the healthcheck `retries: 20` at 5s intervals (100s total) is enough — if not, add a `docker compose ps` debug step before `setup.sh`
- **curl queries fail:** confirm `jq` is available with `which jq`; check the `ARCADEDB_PASS` env var is picked up by `queries.sh`
- **Java build fails:** confirm the Maven cache is being used; check `mvn package -q` output is not suppressing a real error — try without `-q` temporarily
- **Java run fails:** the fat JAR should be at `target/recommendation-engine.jar`; confirm `finalName` in `pom.xml` matches

**Step 3: No further commit needed if both pass**
