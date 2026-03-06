package com.arcadedb.examples;

import org.neo4j.driver.*;
import org.neo4j.driver.Record;

import java.util.List;

public class GraphRAG {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final String PORT     = System.getenv().getOrDefault("ARCADEDB_BOLT_PORT", "7687");
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    String uri = "bolt://" + HOST + ":" + PORT;
    try (Driver driver = GraphDatabase.driver(uri, AuthTokens.basic(USER, PASSWORD))) {
      tryRun(() -> runQuery1GraphTraversal(driver), "Query 1");
      tryRun(() -> runQuery2MultiHopEntityBridge(driver), "Query 2");
      tryRun(() -> runQuery3LatestChunks(driver), "Query 3");
      tryRun(() -> runQuery4CompositeScoring(driver), "Query 4");
      tryRun(() -> runQuery5AgenticRAG(driver), "Query 5");
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

  // Query 1: Graph Traversal with Entity Collection
  // Finds chunks and their mentioned entities via graph traversal
  // (vector search requires SQL; see queries.sh Query 1 for the hybrid version)
  private static void runQuery1GraphTraversal(Driver driver) {
    printHeader("Query 1: Graph Traversal with Entity Collection",
        "Find chunks and their mentioned entities via graph traversal.");

    String cypher = """
        MATCH (chunk:Chunk)-[:MENTIONS]->(entity)
        RETURN chunk.content AS content, chunk.source AS source,
               collect(DISTINCT entity.name) AS entities
        LIMIT 10""";

    try (Session session = driver.session(SessionConfig.forDatabase("GraphRAG"))) {
      Result result = session.run(cypher);
      List<Record> records = result.list();
      for (Record r : records) {
        System.out.printf("  %-40.40s | %-35.35s | %s%n",
            r.get("source").asString(),
            truncate(r.get("content").asString(), 35),
            r.get("entities").asList());
      }
    }
  }

  // Query 2: Multi-Hop Entity Bridge
  // Discovers documents connected through shared entity chains
  private static void runQuery2MultiHopEntityBridge(Driver driver) {
    printHeader("Query 2: Multi-Hop Entity Bridge",
        "Find chunks connected through shared entities from GraphRAG docs.");

    String cypher = """
        MATCH (direct:Chunk)-[:MENTIONS]->(entity)<-[:MENTIONS]-(related:Chunk)
        WHERE direct.source = 'Getting Started with GraphRAG'
          AND related.source <> direct.source
        RETURN direct.source AS source_doc,
               entity.name AS bridge_entity,
               related.content AS connected_content,
               related.source AS connected_doc
        LIMIT 20""";

    try (Session session = driver.session(SessionConfig.forDatabase("GraphRAG"))) {
      Result result = session.run(cypher);
      List<Record> records = result.list();
      for (Record r : records) {
        System.out.printf("  [%s] --%s--> %s%n",
            r.get("source_doc").asString(),
            r.get("bridge_entity").asString(),
            r.get("connected_doc").asString());
        System.out.printf("    -> %s%n", truncate(r.get("connected_content").asString(), 80));
      }
    }
  }

  // Query 3: Latest Chunk Per Document
  // Returns the highest-indexed chunk for each source document
  private static void runQuery3LatestChunks(Driver driver) {
    printHeader("Query 3: Latest Chunk Per Document",
        "Get the highest-indexed chunk per source document.");

    String cypher = """
        MATCH (c:Chunk)
        RETURN c.content AS content, c.source AS source, c.chunkIndex AS chunkIndex
        ORDER BY c.source, c.chunkIndex DESC
        LIMIT 10""";

    try (Session session = driver.session(SessionConfig.forDatabase("GraphRAG"))) {
      Result result = session.run(cypher);
      List<Record> records = result.list();
      for (Record r : records) {
        System.out.printf("  %-40.40s | chunk %d | %s%n",
            r.get("source").asString(),
            r.get("chunkIndex").asInt(),
            truncate(r.get("content").asString(), 50));
      }
    }
  }

  // Query 4: Triple Hybrid — Full-Text + Graph + Entity Count
  // Combines full-text filtering, graph traversal, and entity scoring
  private static void runQuery4CompositeScoring(Driver driver) {
    printHeader("Query 4: Triple Hybrid — Full-Text + Graph + Entity Count",
        "Filter by full-text, rank by entity connections (vector via queries.sh).");

    String cypher = """
        MATCH (chunk:Chunk)
        WHERE chunk.content CONTAINS 'knowledge graph'
        OPTIONAL MATCH (chunk)-[:MENTIONS]->(entity)
        RETURN chunk.content AS content, chunk.source AS source,
               count(entity) AS entity_count
        ORDER BY entity_count DESC
        LIMIT 10""";

    try (Session session = driver.session(SessionConfig.forDatabase("GraphRAG"))) {
      Result result = session.run(cypher);
      List<Record> records = result.list();
      for (Record r : records) {
        System.out.printf("  %-40.40s | entities: %d | %s%n",
            r.get("source").asString(),
            r.get("entity_count").asInt(),
            truncate(r.get("content").asString(), 40));
      }
    }
  }

  // Query 5: Agentic RAG — multi-step retrieval
  // Simulates an agent workflow: graph expansion, then authorship
  private static void runQuery5AgenticRAG(Driver driver) {
    printHeader("Query 5: Agentic RAG (Multi-Step Retrieval)",
        "Simulate an agent: graph expansion -> related concepts -> authorship.");

    try (Session session = driver.session(SessionConfig.forDatabase("GraphRAG"))) {
      // Step 1: Find entities mentioned in GraphRAG docs
      System.out.println("  Step 1: Graph expansion from GraphRAG docs");
      String step1 = """
          MATCH (c:Chunk {source: 'Getting Started with GraphRAG'})
                -[:MENTIONS]->(e)
                -[:RELATES_TO]->(related)
          RETURN e.name AS entity, related.name AS related_concept
          LIMIT 10""";

      Result r1 = session.run(step1);
      List<Record> records1 = r1.list();
      for (Record r : records1) {
        System.out.printf("    %s --> %s%n",
            r.get("entity").asString(),
            r.get("related_concept").asString());
      }

      // Step 2: Get authorship context
      System.out.println("\n  Step 2: Authorship context");
      String step2 = """
          MATCH (p:Person)-[:AUTHORED]->(c:Chunk)
          RETURN p.name AS author, c.source AS document, c.chunkIndex AS chunk
          ORDER BY p.name, c.source
          LIMIT 10""";

      Result r2 = session.run(step2);
      List<Record> records2 = r2.list();
      for (Record r : records2) {
        System.out.printf("    %s authored '%s' (chunk %d)%n",
            r.get("author").asString(),
            r.get("document").asString(),
            r.get("chunk").asInt());
      }

      // Step 3: Team context — who works where
      System.out.println("\n  Step 3: Team context");
      String step3 = """
          MATCH (p:Person)-[:WORKS_AT]->(org:Organization)
          RETURN p.name AS person, org.name AS team
          LIMIT 10""";

      Result r3 = session.run(step3);
      List<Record> records3 = r3.list();
      for (Record r : records3) {
        System.out.printf("    %s works at %s%n",
            r.get("person").asString(),
            r.get("team").asString());
      }
    }
  }

  private static void printHeader(String title, String description) {
    System.out.println("\n" + "=".repeat(70));
    System.out.println("  " + title);
    System.out.println("  " + description);
    System.out.println("=".repeat(70));
  }

  private static String truncate(String s, int maxLen) {
    return s.length() <= maxLen ? s : s.substring(0, maxLen - 3) + "...";
  }
}
