# Realtime Analytics — Grafana Dashboard Design

**Date:** 2026-03-05
**Branch:** feat/realtime-analytics
**ArcadeDB version:** 26.3.1
**Grafana version:** 11.6.0

## Overview

Add a preconfigured Grafana dashboard to the realtime-analytics use case that visualizes sensor and service metrics via ArcadeDB's native PromQL-compatible HTTP endpoints. Zero plugins required — uses the built-in Prometheus data source.

## Architecture

```
┌──────────────┐     PromQL queries      ┌──────────────┐
│   Grafana    │ ──────────────────────>  │   ArcadeDB   │
│  :3000       │  /ts/{db}/prom/api/v1/  │  :2480       │
│  (Prometheus │  query_range            │  (PromQL +   │
│   datasource)│                         │   TimeSeries) │
└──────────────┘                         └──────────────┘
```

Grafana connects to ArcadeDB as a **Prometheus data source**. ArcadeDB exposes standard Prometheus-compatible endpoints:

- `GET /api/v1/ts/{database}/prom/api/v1/query` — instant query
- `GET /api/v1/ts/{database}/prom/api/v1/query_range` — range query (used by Grafana panels)
- `GET /api/v1/ts/{database}/prom/api/v1/labels` — label discovery
- `GET /api/v1/ts/{database}/prom/api/v1/label/{name}/values` — label values
- `GET /api/v1/ts/{database}/prom/api/v1/series` — series discovery

All endpoints return standard Prometheus JSON format. Timestamps in Unix seconds (float).

## PromQL Metric Mapping

ArcadeDB maps time-series types to PromQL metrics:

| ArcadeDB Type | PromQL Metric Name | First Field (value) | Labels (tags) |
|---------------|-------------------|---------------------|---------------|
| `SensorReading` | `SensorReading` | `temperature` | `sensor_id`, `location` |
| `ServiceMetrics` | `ServiceMetrics` | `request_count` | `service_id`, `server_id` |

**Limitation:** PromQL returns only the **first FIELD column** per type. `humidity`, `pressure`, `error_count`, `latency_ms` are not accessible via PromQL. This is acceptable for the demo — temperature and request count are the primary metrics.

## File Structure

```
realtime-analytics/
├── grafana/
│   ├── provisioning/
│   │   └── datasources/
│   │       └── arcadedb.yml
│   └── dashboards/
│       ├── dashboards.yml
│       └── realtime-analytics.json
├── docker-compose.yml              (modified: add grafana service)
└── ...existing files unchanged...
```

## Docker Compose Changes

Add `grafana` service alongside existing `arcadedb`:

```yaml
grafana:
  image: grafana/grafana-oss:11.6.0
  ports:
    - "3000:3000"
  environment:
    GF_AUTH_ANONYMOUS_ENABLED: "true"
    GF_AUTH_ANONYMOUS_ORG_ROLE: Admin
    GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH: /var/lib/grafana/dashboards/realtime-analytics.json
  volumes:
    - ./grafana/provisioning/datasources:/etc/grafana/provisioning/datasources
    - ./grafana/dashboards:/var/lib/grafana/dashboards
  depends_on:
    arcadedb:
      condition: service_healthy
```

- Anonymous auth with Admin role (no login wall for demo)
- Home dashboard set to our preconfigured dashboard
- Volumes mount provisioning configs and dashboard JSON
- Depends on ArcadeDB being healthy (database must exist before Grafana queries)

## Datasource Configuration

`grafana/provisioning/datasources/arcadedb.yml`:

```yaml
apiVersion: 1
datasources:
  - name: ArcadeDB
    type: prometheus
    access: proxy
    url: http://arcadedb:2480/api/v1/ts/RealtimeAnalytics/prom
    basicAuth: true
    basicAuthUser: root
    secureJsonData:
      basicAuthPassword: arcadedb
    isDefault: true
    editable: false
```

Key details:
- Type `prometheus` — Grafana's built-in Prometheus data source
- URL points to ArcadeDB's PromQL endpoint base path for the `RealtimeAnalytics` database
- Basic auth with root/arcadedb credentials
- `access: proxy` — Grafana server-side proxies requests (avoids CORS)

## Dashboard Panels

4 panels on a single dashboard titled "Realtime Analytics":

### Row 1: Sensor Readings

**Panel 1: Temperature by Sensor** (time series, full width)
- Query: `SensorReading`
- Legend: `{{sensor_id}} ({{location}})`
- Shows all 6 sensors with temperature over time
- Each sensor_id becomes a separate series via PromQL label grouping

**Panel 2: Avg Temperature by Location** (time series, half width)
- Query: `avg by (location) (SensorReading)`
- Legend: `{{location}}`
- Compares HQ vs DC average temperature

### Row 2: Service Metrics

**Panel 3: Request Count by Service** (time series, half width)
- Query: `ServiceMetrics`
- Legend: `{{service_id}}`
- Shows raw request counts per service

**Panel 4: Request Rate by Service** (time series, half width)
- Query: `rate(ServiceMetrics[10m])`
- Legend: `{{service_id}}`
- Shows per-second request rate (derived from counter-like request_count)

### Dashboard Settings

- **Time range:** Fixed to `2026-02-20T10:00:00Z` — `2026-02-20T12:00:00Z` (our sample data window)
- **Refresh:** Off (static data)
- **Timezone:** UTC

## Setup Flow

1. `docker compose up -d` starts both ArcadeDB and Grafana
2. `./setup.sh` creates database, loads schema/data/aggregates (unchanged)
3. Grafana auto-provisions the ArcadeDB datasource and dashboard on startup
4. User opens `http://localhost:3000` — dashboard loads immediately with data

No manual Grafana configuration needed.

## CI Impact

The CI workflow runs `setup.sh` then queries. Grafana is not needed for CI (it's a visualization layer). Two options:
- Don't change CI at all (Grafana starts but isn't tested)
- Add a simple `curl -sf http://localhost:3000/api/health` check

Recommend: no CI change. Grafana is optional visualization, not part of the query validation.

## README Changes

Add a "Grafana Dashboard" section to the README with:
- Screenshot placeholder (or description)
- URL: `http://localhost:3000`
- Note that no login is required
- Note the fixed time range for sample data

## Success Criteria

- `docker compose up -d` starts both services
- `./setup.sh` loads data (unchanged)
- `http://localhost:3000` shows the dashboard with 4 populated panels
- All 4 PromQL queries return data in Grafana
- No manual configuration required
