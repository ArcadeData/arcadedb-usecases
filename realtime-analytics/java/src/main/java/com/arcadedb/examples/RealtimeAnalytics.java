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

  // Epoch ms for 2026-02-20: 10:00 = 1771581600000, 12:00 = 1771588800000, 11:30 = 1771587000000
  private static final long TS_10_00 = 1771581600000L;
  private static final long TS_11_30 = 1771587000000L;
  private static final long TS_12_00 = 1771588800000L;

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
          ts.timeBucket('1h', ts) AS hour,
          sensor_id,
          avg(temperature) AS avg_temp,
          max(temperature) AS max_temp,
          ts.percentile(temperature, 0.99) AS p99_temp,
          count(*) AS samples
        FROM SensorReading
        WHERE ts BETWEEN %d AND %d
          AND sensor_id = 's-A'
        GROUP BY hour, sensor_id
        ORDER BY hour""".formatted(TS_10_00, TS_12_00);

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
        "10-minute windowed rate and p99 latency per service.");

    String sql = """
        SELECT
          ts.timeBucket('10m', ts) AS window,
          service_id,
          ts.rate(request_count, ts) AS requests_per_sec,
          ts.percentile(latency_ms, 0.99) AS p99_latency
        FROM ServiceMetrics
        WHERE ts BETWEEN %d AND %d
        GROUP BY window, service_id""".formatted(TS_10_00, TS_12_00);

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
          ts.timeBucket('1m', ts) AS minute,
          ts.interpolate(temperature, 'linear', ts) AS temp_filled
        FROM SensorReading
        WHERE sensor_id = 's-C'
          AND ts BETWEEN %d AND %d
        GROUP BY minute""".formatted(TS_10_00, TS_11_30);

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
        "Traverse HQ building topology, then aggregate sensor readings.");

    // Step 1: Graph traversal to find HQ sensors
    System.out.println("  --- Step 1: Sensors at HQ (MATCH graph traversal) ---");
    String matchSql = """
        SELECT sensor.sensor_id AS sensor_id, sensor.name AS sensor_name
        FROM (
          MATCH {type: Building, where: (name = 'HQ')}
                .out('HAS_FLOOR'){as: floor}
                .in('INSTALLED_IN'){as: sensor}
          RETURN sensor
        )""";

    try (ResultSet rs = db.query("sql", matchSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-10s | %s%n",
            r.getProperty("sensor_id"),
            r.getProperty("sensor_name"));
      }
    }

    // Step 2: Time-series aggregation for HQ sensors
    System.out.println("  --- Step 2: Time-series aggregation ---");
    String tsSql = """
        SELECT
          sensor_id,
          avg(temperature) AS avg_temp,
          max(temperature) AS max_temp,
          count(*) AS samples
        FROM SensorReading
        WHERE sensor_id IN ['s-A', 's-B', 's-C']
          AND ts BETWEEN %d AND %d
        GROUP BY sensor_id""".formatted(TS_10_00, TS_12_00);

    try (ResultSet rs = db.query("sql", tsSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-10s | avg: %.1f | max: %.1f | samples: %s%n",
            r.getProperty("sensor_id"),
            ((Number) r.getProperty("avg_temp")).doubleValue(),
            ((Number) r.getProperty("max_temp")).doubleValue(),
            r.getProperty("samples"));
      }
    }
  }

  // Query 5: Service Impact Analysis
  private static void runQuery5ImpactAnalysis(RemoteDatabase db) {
    printHeader("Query 5: Service Impact Analysis",
        "Find services affected by srv-1 failure with live metrics.");

    // Step 1: Cypher graph traversal for impact chain
    System.out.println("  --- Step 1: Affected services (Cypher dependency traversal) ---");
    String cypher = """
        MATCH (failing:Server {server_id: 'srv-1'})
          <-[:RUNS_ON]-(directSvc:Service)
          -[:DEPENDS_ON*0..3]->(depSvc:Service)
        RETURN DISTINCT depSvc.name AS service_name, depSvc.service_id AS service_id""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-25s | %s%n",
            r.getProperty("service_name"),
            r.getProperty("service_id"));
      }
    }

    // Step 2: Time-series metrics for affected services
    System.out.println("  --- Step 2: Service metrics ---");
    String metricsSql = """
        SELECT
          service_id,
          ts.rate(request_count, ts) AS requests_per_sec,
          sum(error_count) AS total_errors,
          ts.percentile(latency_ms, 0.99) AS p99_latency
        FROM ServiceMetrics
        WHERE ts BETWEEN %d AND %d
        GROUP BY service_id""".formatted(TS_10_00, TS_12_00);

    try (ResultSet rs = db.query("sql", metricsSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-25s | rps: %s | errors: %s | p99: %s ms%n",
            r.getProperty("service_id"),
            r.getProperty("requests_per_sec"),
            r.getProperty("total_errors"),
            r.getProperty("p99_latency"));
      }
    }
  }

  // Query 6: Continuous Aggregate
  private static void runQuery6ContinuousAggregate(RemoteDatabase db) {
    printHeader("Query 6: Continuous Aggregate",
        "Query pre-computed hourly temperature rollup.");

    String sql = """
        SELECT hour, sensor_id, avg_temp, max_temp, min_temp
        FROM hourly_sensor_temps
        WHERE hour BETWEEN %d AND %d
        ORDER BY hour, sensor_id""".formatted(TS_10_00, TS_12_00);

    try (ResultSet rs = db.command("sql", sql)) {
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
