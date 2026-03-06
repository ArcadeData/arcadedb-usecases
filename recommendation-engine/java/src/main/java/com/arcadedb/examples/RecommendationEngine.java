package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;

public class RecommendationEngine {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME  = "RecommendationEngine";
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
      tryRun(() -> runQuery1CollaborativeFiltering(db), "Query 1");
      tryRun(() -> runQuery2VectorSimilarity(db), "Query 2");
      tryRun(() -> runQuery3Trending(db), "Query 3");
      tryRun(() -> runQuery4StreamingHybrid(db), "Query 4");
      tryRun(() -> runQuery5EcommerceCategory(db), "Query 5");
      tryRun(() -> runQuery6HybridMultiModel(db), "Query 6");
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

  // Query 1: Collaborative Filtering via Graph Traversal
  private static void runQuery1CollaborativeFiltering(RemoteDatabase db) {
    printHeader("Query 1: Collaborative Filtering (Graph Traversal)",
        "Find products to recommend to u1 based on shared purchases with other users.");

    String cypher =
        """
            MATCH (me:User {id: 'u1'})
                  -[:PURCHASED]->(p:Product)
                  <-[:PURCHASED]-(other:User)
                  -[:PURCHASED]->(rec:Product)
             WHERE rec <> p
               AND NOT (me)-[:PURCHASED]->(rec)
             RETURN rec.name, rec.category, count(DISTINCT other) AS score
             ORDER BY score DESC LIMIT 20""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | %-15s | score: %s%n",
            r.getProperty("rec.name"),
            r.getProperty("rec.category"),
            r.getProperty("score"));
      }
    }
  }

  // Query 2: Vector Similarity Search
  private static void runQuery2VectorSimilarity(RemoteDatabase db) {
    printHeader("Query 2: Vector Similarity Search",
        "Find products similar to the Laptop embedding [0.9, 0.1, 0.1, 0.1].");

    String sql =
        """
            SELECT name, category, price
             FROM Product
             WHERE inStock = true
             ORDER BY vectorNeighbors('Product[embedding]', [0.9, 0.1, 0.1, 0.1], 20) DESC
             LIMIT 20""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | %-15s | $%-8.2f%n",
            r.getProperty("name"),
            r.getProperty("category"),
            ((Number) r.getProperty("price")).doubleValue());
      }
    }
  }

  // Query 3: Trending Products
  private static void runQuery3Trending(RemoteDatabase db) {
    printHeader("Query 3: Trending Products (Time-Series)",
        "Rank products by total recent purchase interaction counts.");

    String sql =
        """
            SELECT productId, sum(purchaseCount) AS totalInteractions
             FROM ProductInteraction
             GROUP BY productId
             ORDER BY totalInteractions DESC
             LIMIT 10""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | interactions: %s%n",
            r.getProperty("productId"),
            r.getProperty("totalInteractions"));
      }
    }
  }

  // Query 4: Graph Traversal — Streaming Platform
  private static void runQuery4StreamingHybrid(RemoteDatabase db) {
    printHeader("Query 4: Graph Traversal — Streaming Platform",
        "Recommend shows to u1 based on what users with shared watch history also watched.");

    String sql =
        """
            SELECT title, genre, count(*) AS collab_score
             FROM (
              MATCH {type: User, where: (id = 'u1')}
                    .out('WATCHED'){as: show}
                    .in('WATCHED'){as: viewer, where: (id != 'u1')}
                    .out('WATCHED'){as: rec, where: ($matched.show != @this)}
              RETURN rec.title AS title, rec.genre AS genre
             ) GROUP BY title, genre
             ORDER BY collab_score DESC
             LIMIT 10""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | %-15s | collab_score: %s%n",
            r.getProperty("title"),
            r.getProperty("genre"),
            r.getProperty("collab_score"));
      }
    }
  }

  // Query 5: E-Commerce Personalized Category Page
  private static void runQuery5EcommerceCategory(RemoteDatabase db) {
    printHeader("Query 5: E-Commerce Personalized Category Page",
        "Rank Electronics products for u1 by vector relevance.");

    String sql =
        """
            SELECT name, category, price
             FROM Product
             WHERE category = 'Electronics'
               AND inStock = true
             ORDER BY vectorCosineSimilarity(
               embedding,
               (SELECT embedding FROM User WHERE id = 'u1' LIMIT 1)
             ) DESC
             LIMIT 30""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | %-15s | $%-8.2f%n",
            r.getProperty("name"),
            r.getProperty("category"),
            ((Number) r.getProperty("price")).doubleValue());
      }
    }
  }

  // Query 6: Hybrid Multi-Model Recommendation
  private static void runQuery6HybridMultiModel(RemoteDatabase db) {
    printHeader("Query 6: Hybrid Multi-Model Recommendation",
        "Combine graph + vector + time-series for u1.");

    // Step 1: Graph — collaborative filtering candidates
    System.out.println("  --- Step 1: Graph — collaborative filtering candidates ---");
    String cypher =
        """
            MATCH (me:User {id: 'u1'})
                  -[:PURCHASED]->(p:Product)
                  <-[:PURCHASED]-(other:User)
                  -[:PURCHASED]->(rec:Product)
            WHERE rec <> p
              AND NOT (me)-[:PURCHASED]->(rec)
            RETURN DISTINCT rec.name AS name""";

    java.util.List<String> candidates = new java.util.ArrayList<>();
    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        String name = r.getProperty("name");
        candidates.add(name);
        System.out.printf("    %s%n", name);
      }
    }

    if (candidates.isEmpty()) {
      System.out.println("  No candidates found.");
      return;
    }

    // Step 2: Vector — rank candidates by similarity to u1 preference
    System.out.println("  --- Step 2: Vector — rank by similarity to u1 preference ---");
    String candidateList = candidates.stream()
        .map(n -> "'" + n + "'")
        .collect(java.util.stream.Collectors.joining(", "));

    String vectorSql = String.format(
        """
            SELECT name, category, price,
                   vectorCosineSimilarity(
                     embedding,
                     (SELECT embedding FROM User WHERE id = 'u1' LIMIT 1)
                   ) AS preference_score
            FROM Product
            WHERE name IN [%s]
            ORDER BY preference_score DESC""", candidateList);

    try (ResultSet rs = db.query("sql", vectorSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("    %-20s | %-12s | $%-8.2f | pref: %s%n",
            r.getProperty("name"),
            r.getProperty("category"),
            ((Number) r.getProperty("price")).doubleValue(),
            r.getProperty("preference_score"));
      }
    }

    // Step 3: Time-series — trending boost
    System.out.println("  --- Step 3: Time-series — trending boost ---");
    String trendingSql = String.format(
        """
            SELECT productId, sum(purchaseCount) AS trending_score
            FROM ProductInteraction
            WHERE productId IN [%s]
            GROUP BY productId
            ORDER BY trending_score DESC""", candidateList);

    try (ResultSet rs = db.query("sql", trendingSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("    %-20s | trending: %s%n",
            r.getProperty("productId"),
            r.getProperty("trending_score"));
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
