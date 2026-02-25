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
            runQuery1CollaborativeFiltering(db);
            runQuery2VectorSimilarity(db);
            runQuery3Trending(db);
            runQuery4StreamingHybrid(db);
            runQuery5EcommerceCategory(db);
        }
        System.out.println("\nAll queries complete.");
    }

    // Query 1: Collaborative Filtering via Graph Traversal
    private static void runQuery1CollaborativeFiltering(RemoteDatabase db) {
        printHeader("Query 1: Collaborative Filtering (Graph Traversal)",
            "Find products to recommend to u1 based on shared purchases with other users.");

        String cypher =
            "MATCH (me:User {id: 'u1'})" +
            "      -[:PURCHASED]->(p:Product)" +
            "      <-[:PURCHASED]-(other:User)" +
            "      -[:PURCHASED]->(rec:Product)" +
            " WHERE rec <> p" +
            "   AND NOT (me)-[:PURCHASED]->(rec)" +
            " RETURN rec.name, rec.category, count(DISTINCT other) AS score" +
            " ORDER BY score DESC LIMIT 20";

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
            "SELECT name, category, price," +
            "       vectorDistance(embedding, [0.9, 0.1, 0.1, 0.1]) AS distance" +
            " FROM Product" +
            " WHERE inStock = true" +
            " ORDER BY distance ASC" +
            " LIMIT 20";

        try (ResultSet rs = db.query("sql", sql)) {
            while (rs.hasNext()) {
                Result r = rs.next();
                System.out.printf("  %-20s | %-15s | $%-8.2f | distance: %.4f%n",
                    r.getProperty("name"),
                    r.getProperty("category"),
                    ((Number) r.getProperty("price")).doubleValue(),
                    ((Number) r.getProperty("distance")).doubleValue());
            }
        }
    }

    // Query 3: Trending Products
    private static void runQuery3Trending(RemoteDatabase db) {
        printHeader("Query 3: Trending Products (Time-Series)",
            "Rank products by total recent purchase interaction counts.");

        String sql =
            "SELECT productId, sum(purchaseCount) AS totalInteractions" +
            " FROM ProductInteraction" +
            " GROUP BY productId" +
            " ORDER BY totalInteractions DESC" +
            " LIMIT 10";

        try (ResultSet rs = db.query("sql", sql)) {
            while (rs.hasNext()) {
                Result r = rs.next();
                System.out.printf("  %-20s | interactions: %s%n",
                    r.getProperty("productId"),
                    r.getProperty("totalInteractions"));
            }
        }
    }

    // Query 4: Multi-Model Hybrid — Streaming Platform
    private static void runQuery4StreamingHybrid(RemoteDatabase db) {
        printHeader("Query 4: Multi-Model Hybrid — Streaming Platform",
            "Recommend shows to u1 blending collaborative signal + vector similarity.");

        String sql =
            "LET $collab = (" +
            "  SELECT rec, count(DISTINCT viewer) AS collab_score" +
            "  FROM (" +
            "    MATCH {type: User, where: (id = 'u1')}" +
            "          .out('WATCHED'){as: show}" +
            "          .in('WATCHED'){as: viewer, where: (id \!= 'u1')}" +
            "          .out('WATCHED'){as: rec, where: ($matched.show \!= @this)}" +
            "    RETURN rec, viewer" +
            "  ) GROUP BY rec" +
            ")" +
            " SELECT rec.title, rec.genre," +
            "   collab_score," +
            "   vectorDistance(rec.embedding, [0.9, 0.1, 0.1, 0.1]) AS similarity," +
            "   (0.6 * collab_score + 0.4 * (1 - similarity)) AS final_score" +
            " FROM $collab" +
            " ORDER BY final_score DESC" +
            " LIMIT 10";

        try (ResultSet rs = db.query("sql", sql)) {
            while (rs.hasNext()) {
                Result r = rs.next();
                System.out.printf("  %-20s | %-15s | collab: %s | score: %.4f%n",
                    r.getProperty("rec.title"),
                    r.getProperty("rec.genre"),
                    r.getProperty("collab_score"),
                    ((Number) r.getProperty("final_score")).doubleValue());
            }
        }
    }

    // Query 5: E-Commerce Personalized Category Page
    private static void runQuery5EcommerceCategory(RemoteDatabase db) {
        printHeader("Query 5: E-Commerce Personalized Category Page",
            "Rank Electronics products for u1 by vector relevance.");

        String cypher =
            "MATCH (u:User {id: 'u1'})" +
            " MATCH (p:Product)" +
            " WHERE p.category = 'Electronics'" +
            "   AND p.inStock = true" +
            " RETURN p.name, p.price," +
            "   vectorDistance(p.embedding, u.embedding) AS relevance" +
            " ORDER BY relevance ASC" +
            " LIMIT 30";

        try (ResultSet rs = db.query("cypher", cypher)) {
            while (rs.hasNext()) {
                Result r = rs.next();
                System.out.printf("  %-20s | $%-8.2f | relevance: %.4f%n",
                    r.getProperty("p.name"),
                    ((Number) r.getProperty("p.price")).doubleValue(),
                    ((Number) r.getProperty("relevance")).doubleValue());
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
