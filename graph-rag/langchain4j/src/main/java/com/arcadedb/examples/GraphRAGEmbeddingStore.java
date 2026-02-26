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

/**
 * Demonstrates LangChain4j embedding generation combined with ArcadeDB graph
 * storage via the Neo4j Bolt driver.
 *
 * LangChain4j generates 384-dimensional embeddings using AllMiniLmL6V2 (runs
 * in-process, no API keys). The embeddings are stored in ArcadeDB's LCChunk
 * vertex type via Cypher over Bolt.
 *
 * Similarity is computed in-memory using LangChain4j's CosineSimilarity because
 * ArcadeDB's vectorNeighbors() function is SQL-only and not available over the
 * Bolt protocol. For server-side vector search, see queries.sh which uses the
 * HTTP API with vectorNeighbors().
 */
public class GraphRAGEmbeddingStore {

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

      // Clean up any LCChunk nodes from previous runs
      session.run("MATCH (c:LCChunk) DELETE c");

      // Ingest sample chunks with real embeddings via Cypher over Bolt
      String[] texts = {
          "GraphRAG combines knowledge graphs with vector search to improve retrieval accuracy.",
          "Vector similarity search uses embedding models to encode text into high-dimensional vectors.",
          "Microservices decompose applications into small, independently deployable services.",
          "Building a knowledge graph requires extracting entities and relationships from documents."
      };

      for (String text : texts) {
        Embedding embedding = embeddingModel.embed(TextSegment.from(text)).content();
        List<Double> vector = toDoubleList(embedding.vector());
        session.run("CREATE (c:LCChunk {content: $content, embedding: $embedding})",
            Values.parameters("content", text, "embedding", vector));
      }
      System.out.println("Ingested " + texts.length + " chunks with " + embeddingModel.dimension() + "D embeddings.\n");

      // Similarity search: embed query, fetch stored embeddings, rank by cosine similarity
      String query = "How does graph-based retrieval work?";
      Embedding queryEmbedding = embeddingModel.embed(query).content();

      System.out.println("Query: \"" + query + "\"\n");
      System.out.println("Top matches (cosine similarity via LangChain4j):");

      Result result = session.run("MATCH (c:LCChunk) RETURN c.content AS content, c.embedding AS embedding");
      List<ScoredChunk> scored = new ArrayList<>();

      for (Record r : result.list()) {
        String content = r.get("content").asString();
        List<Object> rawEmbedding = r.get("embedding").asList();
        float[] storedVector = new float[rawEmbedding.size()];
        for (int i = 0; i < rawEmbedding.size(); i++) {
          storedVector[i] = ((Number) rawEmbedding.get(i)).floatValue();
        }
        double score = CosineSimilarity.between(queryEmbedding, new Embedding(storedVector));
        scored.add(new ScoredChunk(content, score));
      }

      scored.sort(Comparator.comparingDouble(ScoredChunk::score).reversed());
      for (int i = 0; i < Math.min(3, scored.size()); i++) {
        System.out.printf("  [%.4f] %s%n", scored.get(i).score(), scored.get(i).content());
      }
    }
  }

  private record ScoredChunk(String content, double score) {}

  private static List<Double> toDoubleList(float[] vector) {
    List<Double> list = new ArrayList<>(vector.length);
    for (float f : vector) list.add((double) f);
    return list;
  }
}
