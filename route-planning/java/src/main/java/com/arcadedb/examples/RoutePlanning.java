package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;

import java.util.List;
import java.util.Map;

public class RoutePlanning {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME  = "RoutePlanning";
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  // The endpoints of the trip, resolved by name; the path functions take vertices
  private static final String FROM_TO =
      " LET $from = (SELECT FROM Junction WHERE name = 'Tallahassee'), $to = (SELECT FROM Junction WHERE name = 'Coral Gables')";

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
      tryRun(() -> runQuery1FewestHops(db), "Query 1");
      tryRun(() -> runQuery2Dijkstra(db), "Query 2");
      tryRun(() -> runQuery3AStar(db), "Query 3");
      tryRun(() -> runQuery4ContractionHierarchy(db), "Query 4");
      tryRun(() -> runQuery5ShortestVsFastest(db), "Query 5");
      tryRun(() -> runQuery6LiveTraffic(db), "Query 6");
      tryRun(() -> runQuery7WhichEngine(db), "Query 7");
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

  // Query 1: Fewest Hops
  private static void runQuery1FewestHops(RemoteDatabase db) {
    printHeader("Query 1: Fewest Hops",
        "Tallahassee to Coral Gables with the fewest road segments, ignoring how long they are.");
    printSql(db, "shortestPath($from, $to, 'OUT', 'ROAD')");
  }

  // Query 2: Dijkstra
  private static void runQuery2Dijkstra(RemoteDatabase db) {
    printHeader("Query 2: Dijkstra",
        "The fastest route, by travel time: the number of junctions on it.");
    printSql(db, "dijkstra($from, $to, 'minutes', { direction: 'OUT', edgeTypeNames: ['ROAD'] })");
  }

  // Query 3: A*
  private static void runQuery3AStar(RemoteDatabase db) {
    printHeader("Query 3: A*",
        "The same route, guided by the coordinates (57 minutes per degree never overshoots a road).");
    printSql(db, """
        astar($from, $to, 'minutes', { direction: 'OUT', edgeTypeNames: ['ROAD'],
                                       vertexAxisNames: ['lat', 'lon'], heuristicFormula: 'EUCLIDEAN',
                                       dFactor: 57, tieBreaker: false })""");
  }

  // Query 4: Contraction Hierarchy
  private static void runQuery4ContractionHierarchy(RemoteDatabase db) {
    printHeader("Query 4: Contraction Hierarchy",
        "The same route answered by the CCH kept on the 'Florida' view, in SQL and in Cypher.");
    printSql(db, "cchShortestPath($from, $to, 'minutes', { direction: 'OUT', edgeTypeNames: ['ROAD'] })");
    printRoute(db, "minutes", "km");
  }

  // Query 5: Shortest vs Fastest
  private static void runQuery5ShortestVsFastest(RemoteDatabase db) {
    printHeader("Query 5: Shortest vs Fastest",
        "The route that minimizes km, and the one that minimizes minutes, each with its other cost.");
    printRoute(db, "km", "minutes");
    printRoute(db, "minutes", "km");
  }

  // Query 6: Live Traffic
  private static void runQuery6LiveTraffic(RemoteDatabase db) {
    printHeader("Query 6: Live Traffic",
        "Four hours of queue on the Turnpike south of Orlando, then the fastest route again.");
    String jam = "MATCH (:Junction {id: 702459})-[r:ROAD]->(:Junction {id: 702911}) SET r.minutes = $minutes";

    db.command("cypher", jam, Map.of("minutes", 240));
    System.out.println("  -- SET r.minutes = 240 on the Turnpike segment from junction 702459 to 702911");
    printRoute(db, "minutes", "km");
    db.command("cypher", jam, Map.of("minutes", 6.3009));
    System.out.println("  -- traffic clears: minutes back to 6.3009");
  }

  // Query 7: Which Engine Answered
  private static void runQuery7WhichEngine(RemoteDatabase db) {
    printHeader("Query 7: Which Engine Answered",
        "Each hierarchy counts the queries it answered and the ones it handed to bidirectional Dijkstra.");

    try (ResultSet rs = db.query("sql",
        "SELECT contractionHierarchies FROM schema:graphAnalyticalViews WHERE name = 'Florida'")) {
      List<Map<String, Object>> hierarchies = rs.next().getProperty("contractionHierarchies");
      for (Map<String, Object> h : hierarchies)
        System.out.printf("  %-8s | %-6s | arcs: %,d | queries: %4s | fallbacks: %3s | last update: %s us%n",
            h.get("weightProperty"), h.get("status"), ((Number) h.get("arcs")).longValue(), h.get("queries"), h.get("fallbacks"),
            h.get("lastIncrementalUpdateMicros"));
    }
  }

  /** A SQL path function returns the junctions of the route, in order: here only their number, and the time it took. */
  private static void printSql(RemoteDatabase db, String pathFunction) {
    long begin = System.nanoTime();
    try (ResultSet rs = db.query("sql", "SELECT " + pathFunction + ".size() AS junctions" + FROM_TO)) {
      Object junctions = rs.next().getProperty("junctions");
      System.out.printf("  %s junctions in %,.1f ms%n", junctions, (System.nanoTime() - begin) / 1e6);
    }
  }

  /** algo.cch.shortestPath yields the path (nodes, relationships, length) and its total weight. */
  private static void printRoute(RemoteDatabase db, String cost, String other) {
    String cypher =
        """
            MATCH (a:Junction {name: 'Tallahassee'}), (b:Junction {name: 'Coral Gables'})
            CALL algo.cch.shortestPath(a, b, 'ROAD', $cost, 'OUT') YIELD path, weight
            RETURN weight, reduce(total = 0.0, r IN path.relationships | total + r[$other]) AS other""";

    long begin = System.nanoTime();
    try (ResultSet rs = db.query("cypher", cypher, Map.of("cost", cost, "other", other))) {
      Result r = rs.next();
      System.out.printf("  by %-7s: %,.1f %s (%,.1f %s) in %,.1f ms%n", cost, ((Number) r.getProperty("weight")).doubleValue(), cost,
          ((Number) r.getProperty("other")).doubleValue(), other, (System.nanoTime() - begin) / 1e6);
    }
  }

  private static void printHeader(String title, String description) {
    System.out.println("\n" + "=".repeat(70));
    System.out.println("  " + title);
    System.out.println("  " + description);
    System.out.println("=".repeat(70));
  }
}
