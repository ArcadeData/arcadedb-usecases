# Fraud Detection CI Workflow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create `.github/workflows/fraud-detection.yml` — a matrix CI workflow that verifies both the `curl` and `java` runners for the fraud-detection use case on every push and pull request.

**Architecture:** One `test` job with `matrix: runner: [curl, java]`. Each entry is self-contained: it starts ArcadeDB 26.3.1-SNAPSHOT via `docker compose up -d`, runs `./setup.sh` to load schema and data, runs the language-specific command, then tears down with `if: always()`. Pass criterion is exit code 0. Mirrors `.github/workflows/recommendation-engine.yml` exactly — same action versions, same SHA pins, same step structure.

**Tech Stack:** GitHub Actions, `actions/checkout@v6` (SHA `de0fac2e`), `actions/setup-java@v5` (SHA `be666c2f`, temurin 21), `actions/cache@v5` (SHA `cdf6c1fa`), Docker Compose, Maven 3.x, Java 21, bash/curl/jq (pre-installed on `ubuntu-latest`)

---

### Task 1: Create the workflow file

**Files:**
- Create: `.github/workflows/fraud-detection.yml`

**Step 1: Write the file**

```yaml
name: Fraud Detection CI

on:
  push:
    paths:
      - fraud-detection/**
      - .github/workflows/fraud-detection.yml
  pull_request:
    paths:
      - fraud-detection/**
      - .github/workflows/fraud-detection.yml

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
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          fetch-depth: 1

      - name: Set up Java
        if: matrix.runner == 'java'
        uses: actions/setup-java@be666c2fcd27ec809703dec50e508c2fdc7f6654 # v5.2.0
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: Cache Maven repository
        if: matrix.runner == 'java'
        uses: actions/cache@cdf6c1fa76f9f475f3d7449005a359c84ca0f306 # v5.0.3
        with:
          path: ~/.m2
          key: ${{ runner.os }}-m2-${{ hashFiles('fraud-detection/java/pom.xml') }}
          restore-keys: ${{ runner.os }}-m2-

      - name: Start ArcadeDB
        working-directory: fraud-detection
        run: docker compose up -d

      - name: Setup database
        working-directory: fraud-detection
        run: ./setup.sh

      - name: Run curl queries
        if: matrix.runner == 'curl'
        working-directory: fraud-detection
        run: ./queries/queries.sh

      - name: Build and run Java
        if: matrix.runner == 'java'
        working-directory: fraud-detection/java
        run: |
          mvn package --no-transfer-progress
          java -jar target/fraud-detection.jar

      - name: Teardown
        if: always()
        working-directory: fraud-detection
        run: docker compose down
```

**Step 2: Validate YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/fraud-detection.yml'))" && echo "YAML valid"
```

Expected: `YAML valid`

**Step 3: Commit**

```bash
git add .github/workflows/fraud-detection.yml
git commit -m "ci: add fraud-detection workflow (curl + java matrix)"
```

---

### Task 2: Verify the workflow triggers

**Step 1: Push the branch and check GitHub Actions**

```bash
git push origin feat/fraud-detection
```

Open: `https://github.com/arcadedata/arcadedb-usecases/actions`

Expected: a `Fraud Detection CI` run appears with two jobs — `test (curl)` and `test (java)`.

**Step 2: Confirm both jobs pass**

Both `test (curl)` and `test (java)` should show green checkmarks. If either fails, check the step-level logs:

- **Start ArcadeDB fails:** confirm `docker compose up -d` runs from the `fraud-detection/` directory — check `working-directory`. Note: uses `arcadedata/arcadedb:26.3.1-SNAPSHOT` which must be available on Docker Hub; if the image doesn't exist yet, the job will fail at this step
- **Setup database fails:** `setup.sh` may be timing out waiting for ArcadeDB; check if the healthcheck `retries: 20` at 5s intervals (100s total) is enough — if not, add a `docker compose ps` debug step before `setup.sh`
- **curl queries fail:** confirm `jq` is available with `which jq`; check the `ARCADEDB_PASS` env var is picked up by `queries.sh`. Some queries use ArcadeDB 26.3.1-SNAPSHOT features (`time_bucket`, `vectorDistance`, `full_name.similarity`) — if the server version doesn't support them, the query will return an error
- **Java build fails:** the `arcadedb-network:26.3.1-SNAPSHOT` dependency must be available in Maven Central or a configured snapshot repository; if not, `mvn package` will fail resolving dependencies
- **Java run fails:** the fat JAR should be at `target/fraud-detection.jar`; confirm `finalName` in `pom.xml` matches

**Step 3: No further commit needed if both pass**
