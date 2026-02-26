package com.arcadedb.examples;

import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.embedding.onnx.allminilml6v2.AllMiniLmL6V2EmbeddingModel;
import dev.langchain4j.store.embedding.CosineSimilarity;

import org.neo4j.driver.*;
import org.neo4j.driver.Record;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Demonstrates a Graph RAG content retrieval pipeline that combines LangChain4j
 * embeddings with ArcadeDB's graph traversal via the Neo4j Bolt driver.
 *
 * Pipeline: embed query → vector similarity for chunks → graph expansion
 * to find related entities → return enriched context.
 */
public class GraphRAGContentRetriever {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final String PORT     = System.getenv().getOrDefault("ARCADEDB_BOLT_PORT", "7687");
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    EmbeddingModel embeddingModel = new AllMiniLmL6V2EmbeddingModel();
    System.out.println("Embedding model: AllMiniLmL6V2 (" + embeddingModel.dimension() + "D)\n");

    String uri = "bolt://" + HOST + ":" + PORT;
    try (Driver driver = GraphDatabase.driver(uri, AuthTokens.basic(USER, PASSWORD));
         Session session = driver.session(SessionConfig.forDatabase("GraphRAG"))) {

      // Step 1: Re-embed the existing Chunk data with real 384D vectors
      System.out.println("Step 1: Re-embedding existing chunks with 384D vectors...");
      Result chunks = session.run("MATCH (c:Chunk) RETURN c.content AS content, c.source AS source");
      List<EmbeddedChunk> embeddedChunks = new ArrayList<>();

      for (Record r : chunks.list()) {
        String content = r.get("content").asString();
        String source = r.get("source").asString();
        Embedding embedding = embeddingModel.embed(TextSegment.from(content)).content();
        embeddedChunks.add(new EmbeddedChunk(content, source, embedding));
      }
      System.out.println("  Embedded " + embeddedChunks.size() + " chunks with 384D vectors.\n");

      // Step 2: Run queries — semantic search + graph enrichment
      String[] queries = {
          "How does graph-based retrieval work?",
          "What are vector embeddings?",
          "Tell me about microservices architecture"
      };

      for (String q : queries) {
        System.out.println("Query: \"" + q + "\"");
        Embedding queryEmbedding = embeddingModel.embed(q).content();

        // Find top-3 most similar chunks
        List<ScoredChunk> scored = embeddedChunks.stream()
            .map(ec -> new ScoredChunk(ec, CosineSimilarity.between(queryEmbedding, ec.embedding())))
            .sorted(Comparator.comparingDouble(ScoredChunk::score).reversed())
            .limit(3)
            .toList();

        System.out.println("  Semantic matches:");
        for (ScoredChunk sc : scored) {
          System.out.printf("    [%.4f] [%s] %s%n",
              sc.score(), sc.chunk().source(), truncate(sc.chunk().content(), 70));
        }

        // Step 3: Graph expansion — find entities mentioned by top match
        String topSource = scored.get(0).chunk().source();
        Result entities = session.run(
            "MATCH (c:Chunk)-[:MENTIONS]->(e) WHERE c.source = $source " +
                "RETURN DISTINCT e.name AS entity LIMIT 5",
            Values.parameters("source", topSource));

        List<Record> entityList = entities.list();
        if (!entityList.isEmpty()) {
          System.out.print("  Graph context: ");
          System.out.println(entityList.stream()
              .map(r -> r.get("entity").asString())
              .collect(Collectors.joining(", ")));
        }
        System.out.println();
      }
    }
  }

  private record EmbeddedChunk(String content, String source, Embedding embedding) {}
  private record ScoredChunk(EmbeddedChunk chunk, double score) {}

  private static String truncate(String s, int maxLen) {
    return s.length() <= maxLen ? s : s.substring(0, maxLen - 3) + "...";
  }
}
