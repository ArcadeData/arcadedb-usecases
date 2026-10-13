package com.arcadedb.examples;

import com.arcadedb.database.Database;
import com.arcadedb.database.DatabaseFactory;
import com.arcadedb.database.RID;
import com.arcadedb.graph.GraphBatch;
import com.arcadedb.graph.olap.ContractionHierarchy;
import com.arcadedb.graph.olap.GraphAnalyticalView;
import com.arcadedb.graph.olap.GraphAnalyticalViewRegistry;
import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.zip.GZIPInputStream;

/**
 * The route planning use case in an embedded database: the DIMACS Florida road network (1,070,376 junctions,
 * 2,712,798 road segments) loaded with the GraphBatch API, then Tallahassee to Coral Gables with Dijkstra, A* and a
 * Customizable Contraction Hierarchy, the shortest against the fastest route, and a traffic jam.
 * <p>
 * Run it from the route-planning directory, with Java 21+ and the lib folder of an ArcadeDB 26.10.2+ distribution. It
 * downloads the road network into data/ the first time (about 38 MB), as setup.sh does:
 * <pre>
 *   java -Xmx4g -cp "$ARCADEDB_HOME/lib/*" embedded/FloridaRoutes.java
 * </pre>
 */
public class FloridaRoutes {
  private static final String DIMACS = "https://www.diag.uniroma1.it/challenge9/data/";

  public static void main(final String[] args) throws Exception {
    final Path distances = download("USA-road-d/USA-road-d.FLA.gr.gz");
    final Path times = download("USA-road-t/USA-road-t.FLA.gr.gz");
    final Path coordinates = download("USA-road-d/USA-road-d.FLA.co.gz");

    final DatabaseFactory factory = new DatabaseFactory("./target/databases/florida-routes");
    if (factory.exists())
      factory.open().drop();

    try (final Database db = factory.create()) {
      // 1. The road network, loaded with GraphBatch: vertices in one pass, then the edges with both costs
      runFile(db, Path.of("sql/01-schema.sql"));
      long begin = System.nanoTime();
      final RID[] junctions = loadJunctions(db, coordinates);
      final long edges = loadRoads(db, junctions, distances, times);
      System.out.printf("Loaded %,d junctions and %,d roads in %,d ms%n", junctions.length, edges, (System.nanoTime() - begin) / 1_000_000);
      runFile(db, Path.of("sql/02-places.sql"));

      // 2. A Graph Analytical View keeping one contraction hierarchy per cost: distance and travel time
      //    CREATE GRAPH ANALYTICAL VIEW IF NOT EXISTS Florida EDGE TYPES (ROAD) UPDATE MODE SYNCHRONOUS CCH (km, minutes)
      begin = System.nanoTime();
      runFile(db, Path.of("sql/03-view.sql"));
      final GraphAnalyticalView view = GraphAnalyticalViewRegistry.get(db, "Florida");
      view.awaitReady(5, TimeUnit.MINUTES);
      for (final ContractionHierarchy cch : view.getContractionHierarchies())
        cch.awaitReady(false, 5, TimeUnit.MINUTES);
      System.out.printf("View and hierarchies ready in %,d ms%n", (System.nanoTime() - begin) / 1_000_000);

      // 3. The same trip, three algorithms, one answer
      System.out.printf("%nTallahassee -> Coral Gables, fastest route%n");
      final String from = " LET $from = (SELECT FROM Junction WHERE name = 'Tallahassee'), $to = (SELECT FROM Junction WHERE name = 'Coral Gables')";
      time(db, "dijkstra()", "SELECT dijkstra($from, $to, 'minutes', { direction: 'OUT', edgeTypeNames: ['ROAD'] }).size() AS junctions" + from, 3);
      // A*: lat/lon as the heuristic axes; 57 minutes per degree is the most that never overshoots a road of Florida
      time(db, "astar()", "SELECT astar($from, $to, 'minutes', { direction: 'OUT', edgeTypeNames: ['ROAD'], vertexAxisNames: ['lat', 'lon'], "
          + "heuristicFormula: 'EUCLIDEAN', dFactor: 57, tieBreaker: false }).size() AS junctions" + from, 3);
      // name the edge types the view covers: a search over every type cannot use a hierarchy built on ROAD only
      time(db, "cchShortestPath()", "SELECT cchShortestPath($from, $to, 'minutes', { direction: 'OUT', edgeTypeNames: ['ROAD'] }).size() AS junctions" + from, 21);

      // 4. Two costs, two routes
      route(db, "minutes", "km");
      route(db, "km", "minutes");

      // 5. Live traffic: four hours of queue on the Turnpike south of Orlando. Only the hierarchy's arcs above that road
      //    are re-computed, right after the commit; a query that runs before that is answered by Dijkstra, exactly
      final String jam = "MATCH (:Junction {id: 702459})-[r:ROAD]->(:Junction {id: 702911}) SET r.minutes = $minutes";
      db.transaction(() -> db.command("opencypher", jam, Map.of("minutes", 240)).close());
      System.out.printf("%n-- 4 hours of queue south of Orlando%n");
      route(db, "minutes", "km");
      db.transaction(() -> db.command("opencypher", jam, Map.of("minutes", 6.3009)).close());

      // 6. What answered: every hierarchy counts its queries and the ones it had to hand to Dijkstra
      try (final ResultSet rs = db.query("sql", "SELECT contractionHierarchies FROM schema:graphAnalyticalViews WHERE name = 'Florida'")) {
        System.out.println();
        for (final Map<String, Object> cch : rs.next().<List<Map<String, Object>>>getProperty("contractionHierarchies"))
          System.out.printf("CCH on %-7s status=%s arcs=%,d queries=%s fallbacks=%s lastUpdate=%s us%n", cch.get("weightProperty"),
              cch.get("status"), ((Number) cch.get("arcs")).longValue(), cch.get("queries"), cch.get("fallbacks"),
              cch.get("lastIncrementalUpdateMicros"));
      }
    }
  }

  /** One vertex per junction, in DIMACS order: junctions[id - 1] is the junction with that DIMACS id. */
  private static RID[] loadJunctions(final Database db, final Path coordinates) throws Exception {
    final List<Object[]> properties = new ArrayList<>(1_100_000);
    try (final BufferedReader reader = gzip(coordinates)) {
      String line;
      while ((line = reader.readLine()) != null)
        if (line.startsWith("v ")) {
          final String[] p = line.split(" ");
          properties.add(new Object[] { "id", Integer.parseInt(p[1]), "lat", Integer.parseInt(p[3]) / 1e6, "lon", Integer.parseInt(p[2]) / 1e6 });
        }
    }
    try (final GraphBatch batch = db.batch().build()) {
      return batch.createVertices("Junction", properties.toArray(new Object[0][]));
    }
  }

  /** The two DIMACS graphs list the same arcs in the same order: the length from one, the travel time from the other. */
  private static long loadRoads(final Database db, final RID[] junctions, final Path distances, final Path times) throws Exception {
    long edges = 0;
    try (final BufferedReader d = gzip(distances); final BufferedReader t = gzip(times);
        final GraphBatch batch = db.batch().withBatchSize(500_000).withExpectedEdgeCount(2_712_798).build()) {
      String ld, lt;
      while ((ld = d.readLine()) != null && (lt = t.readLine()) != null) {
        if (!ld.startsWith("a "))
          continue;
        final String[] a = ld.split(" ");
        final String[] b = lt.split(" ");
        // length in tenths of a meter; travel time in millionths of an hour
        batch.newEdge(junctions[Integer.parseInt(a[1]) - 1], "ROAD", junctions[Integer.parseInt(a[2]) - 1],
            "km", Integer.parseInt(a[3]) / 10_000.0, "minutes", Integer.parseInt(b[3]) * 0.00006);
        edges++;
      }
    }
    return edges;
  }

  private static void time(final Database db, final String name, final String sql, final int runs) {
    final double[] ms = new double[runs];
    Object junctions = null;
    for (int r = 0; r < runs; r++) {
      final long begin = System.nanoTime();
      try (final ResultSet rs = db.query("sql", sql)) {
        junctions = rs.next().getProperty("junctions");
      }
      ms[r] = (System.nanoTime() - begin) / 1e6;
    }
    Arrays.sort(ms);
    System.out.printf("  %-18s %,10.1f ms  (median of %d)  %s junctions%n", name, ms[runs / 2], runs, junctions);
  }

  /** The route that minimizes one cost, with the other cost of the same route. */
  private static void route(final Database db, final String cost, final String other) {
    try (final ResultSet rs = db.query("opencypher", """
        MATCH (a:Junction {name: 'Tallahassee'}), (b:Junction {name: 'Coral Gables'})
        CALL algo.cch.shortestPath(a, b, 'ROAD', $cost, 'OUT') YIELD path, weight
        RETURN weight, reduce(total = 0.0, r IN path.relationships | total + r[$other]) AS other, size(path.nodes) AS junctions""",
        Map.of("cost", cost, "other", other))) {
      final Result row = rs.next();
      System.out.printf("  by %-7s: %,.1f %s (%,.1f %s), %s junctions%n", cost, row.<Number>getProperty("weight").doubleValue(), cost,
          row.<Number>getProperty("other").doubleValue(), other, row.getProperty("junctions"));
    }
  }

  /** Runs a file of the use case: DDL as is, UPDATEs in a transaction. */
  private static void runFile(final Database db, final Path file) throws Exception {
    for (final String line : Files.readAllLines(file)) {
      final String statement = line.strip();
      if (statement.isEmpty() || statement.startsWith("--"))
        continue;
      final String sql = statement.endsWith(";") ? statement.substring(0, statement.length() - 1) : statement;
      if (sql.startsWith("UPDATE"))
        db.transaction(() -> db.command("sql", sql).close());
      else
        db.command("sql", sql).close();
    }
  }

  private static Path download(final String file) throws Exception {
    final Path path = Path.of("data", file.substring(file.indexOf('/') + 1));
    if (!Files.exists(path)) {
      Files.createDirectories(path.getParent());
      System.out.println("Downloading " + DIMACS + file + "...");
      HttpClient.newBuilder().followRedirects(HttpClient.Redirect.NORMAL).build()
          .send(HttpRequest.newBuilder(URI.create(DIMACS + file)).build(), HttpResponse.BodyHandlers.ofFile(path));
    }
    return path;
  }

  private static BufferedReader gzip(final Path path) throws Exception {
    return new BufferedReader(new InputStreamReader(new GZIPInputStream(Files.newInputStream(path), 1 << 16), StandardCharsets.US_ASCII), 1 << 16);
  }
}
