package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;

public class RealtimeAnalytics {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME  = "RealtimeAnalytics";
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
      tryRun(() -> runQuery1HourlyBucketing(db), "Query 1");
      tryRun(() -> runQuery2ServiceRate(db), "Query 2");
      tryRun(() -> runQuery3Interpolation(db), "Query 3");
      tryRun(() -> runQuery4GraphTimeSeries(db), "Query 4");
      tryRun(() -> runQuery5ImpactAnalysis(db), "Query 5");
      tryRun(() -> runQuery6ContinuousAggregate(db), "Query 6");
    }
    System.out.println("\nAll queries complete.");
  }

  private static void tryRun(Runnable r, String name) {
    try {
      r.run();
    } catch (Exception e) {
      System.err.println("[" + name + " FAILED] " + e.getMessage());
    }
  }

  // Query 1: Hourly Temperature Bucketing
  private static void runQuery1HourlyBucketing(RemoteDatabase db) {
    printHeader("Query 1: Hourly Temperature Bucketing",
        "Aggregate sensor s-A readings into 1-hour buckets.");

    String sql = """
        SELECT
          time_bucket('1h', ts) AS hour,
          sensor_id,
          avg(temperature) AS avg_temp,
          max(temperature) AS max_temp,
          percentile(temperature, 0.99) AS p99_temp,
          count(*) AS samples
        FROM SensorReading
        WHERE ts BETWEEN '2026-02-20T10:00:00Z' AND '2026-02-20T12:00:00Z'
          AND sensor_id = 's-A'
        GROUP BY hour, sensor_id
        ORDER BY hour""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %s | sensor: %s | avg: %.1f | max: %.1f | p99: %s | samples: %s%n",
            r.getProperty("hour"),
            r.getProperty("sensor_id"),
            ((Number) r.getProperty("avg_temp")).doubleValue(),
            ((Number) r.getProperty("max_temp")).doubleValue(),
            r.getProperty("p99_temp"),
            r.getProperty("samples"));
      }
    }
  }

  // Query 2: Service Request Rate & Latency
  private static void runQuery2ServiceRate(RemoteDatabase db) {
    printHeader("Query 2: Service Request Rate & Latency",
        "5-minute windowed rate and p99 latency per service.");

    String sql = """
        SELECT
          time_bucket('5m', ts) AS window,
          service_id,
          rate(request_count) AS requests_per_sec,
          percentile(latency_ms, 0.99) AS p99_latency
        FROM ServiceMetrics
        WHERE ts BETWEEN '2026-02-20T10:00:00Z' AND '2026-02-20T12:00:00Z'
        GROUP BY window, service_id""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %s | %-25s | rps: %s | p99: %s ms%n",
            r.getProperty("window"),
            r.getProperty("service_id"),
            r.getProperty("requests_per_sec"),
            r.getProperty("p99_latency"));
      }
    }
  }

  // Query 3: Gap Filling with Interpolation
  private static void runQuery3Interpolation(RemoteDatabase db) {
    printHeader("Query 3: Gap Filling with Interpolation",
        "Fill missing temperature readings for sensor s-C.");

    String sql = """
        SELECT
          time_bucket('1m', ts) AS minute,
          interpolate(temperature, 'linear', ts) AS temp_filled
        FROM SensorReading
        WHERE sensor_id = 's-C'
          AND ts BETWEEN '2026-02-20T10:00:00Z' AND '2026-02-20T11:30:00Z'
        GROUP BY minute""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %s | temp: %s%n",
            r.getProperty("minute"),
            r.getProperty("temp_filled"));
      }
    }
  }

  // Query 4: Graph + Time-Series Correlation
  private static void runQuery4GraphTimeSeries(RemoteDatabase db) {
    printHeader("Query 4: Graph + Time-Series Correlation",
        "Traverse HQ building topology, join sensors to their readings.");

    String sql = """
        SELECT
          sensor.name,
          avg(ts.temperature) AS avg_temp,
          max(ts.temperature) AS max_temp,
          count(*) AS samples
        FROM (
          TRAVERSE out('HAS_FLOOR').out('INSTALLED_IN')
          FROM (SELECT FROM Building WHERE name = 'HQ')
          WHILE $depth <= 2
        ) AS sensor
        WHERE sensor.@type = 'Sensor'
          AND ts.ts BETWEEN '2026-02-20T10:00:00Z' AND '2026-02-20T12:00:00Z'
        TIMESERIES sensor -> SensorReading AS ts
        GROUP BY sensor.name""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | avg: %.1f | max: %.1f | samples: %s%n",
            r.getProperty("sensor.name"),
            ((Number) r.getProperty("avg_temp")).doubleValue(),
            ((Number) r.getProperty("max_temp")).doubleValue(),
            r.getProperty("samples"));
      }
    }
  }

  // Query 5: Service Impact Analysis (Cypher)
  private static void runQuery5ImpactAnalysis(RemoteDatabase db) {
    printHeader("Query 5: Service Impact Analysis (Cypher)",
        "Find services affected by srv-1 failure with live metrics.");

    String cypher = """
        MATCH (failing:Server {server_id: 'srv-1'})
          <-[:RUNS_ON]-(svc:Service)
        RETURN svc.name,
          ts.rate(svc, 'ServiceMetrics', 'request_count',
            datetime('2026-02-20T09:50:00Z'), datetime('2026-02-20T10:10:00Z')) AS current_rps,
          ts.last(svc, 'ServiceMetrics', 'error_count') AS errors""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-25s | rps: %s | errors: %s%n",
            r.getProperty("svc.name"),
            r.getProperty("current_rps"),
            r.getProperty("errors"));
      }
    }
  }

  // Query 6: Continuous Aggregate
  private static void runQuery6ContinuousAggregate(RemoteDatabase db) {
    printHeader("Query 6: Continuous Aggregate",
        "Query pre-computed hourly temperature rollup.");

    String sql = """
        SELECT *
        FROM hourly_sensor_temps
        WHERE hour BETWEEN '2026-02-20T10:00:00Z' AND '2026-02-20T12:00:00Z'
        ORDER BY hour, sensor_id""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %s | %-5s | avg: %s | max: %s | min: %s%n",
            r.getProperty("hour"),
            r.getProperty("sensor_id"),
            r.getProperty("avg_temp"),
            r.getProperty("max_temp"),
            r.getProperty("min_temp"));
      }
    }
  }

  private static void printHeader(String title, String description) {
    System.out.println("\n" + "=".repeat(70));
    System.out.println("  " + title);
    System.out.println("  " + description);
    System.out.println("=".repeat(70));
  }
}
