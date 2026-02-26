package com.arcadedb.examples;

import dev.langchain4j.community.store.embedding.neo4j.Neo4jEmbeddingStore;
import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.embedding.onnx.allminilml6v2.AllMiniLmL6V2EmbeddingModel;
import dev.langchain4j.store.embedding.EmbeddingMatch;
import dev.langchain4j.store.embedding.EmbeddingSearchRequest;
import dev.langchain4j.store.embedding.EmbeddingStore;

import java.util.List;

public class GraphRAGEmbeddingStore {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final String PORT     = System.getenv().getOrDefault("ARCADEDB_BOLT_PORT", "2424");
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    EmbeddingModel embeddingModel = new AllMiniLmL6V2EmbeddingModel();

    String boltUrl = "bolt://" + HOST + ":" + PORT;
    EmbeddingStore<TextSegment> store = Neo4jEmbeddingStore.builder()
        .withBasicAuth(boltUrl, USER, PASSWORD)
        .dimension(embeddingModel.dimension())
        .build();

    // Ingest sample chunks
    String[] texts = {
        "GraphRAG combines knowledge graphs with vector search to improve retrieval accuracy.",
        "Vector similarity search uses embedding models to encode text into high-dimensional vectors.",
        "Microservices decompose applications into small, independently deployable services.",
        "Building a knowledge graph requires extracting entities and relationships from documents."
    };

    for (String text : texts) {
      TextSegment segment = TextSegment.from(text);
      Embedding embedding = embeddingModel.embed(segment).content();
      store.add(embedding, segment);
    }

    System.out.println("Ingested " + texts.length + " chunks with 384D embeddings.\n");

    // Similarity search
    String query = "How does graph-based retrieval work?";
    Embedding queryEmbedding = embeddingModel.embed(query).content();
    EmbeddingSearchRequest request = EmbeddingSearchRequest.builder()
        .queryEmbedding(queryEmbedding)
        .maxResults(3)
        .build();

    List<EmbeddingMatch<TextSegment>> matches = store.search(request).matches();

    System.out.println("Query: \"" + query + "\"\n");
    System.out.println("Top matches:");
    for (EmbeddingMatch<TextSegment> match : matches) {
      System.out.printf("  [%.4f] %s%n", match.score(), match.embedded().text());
    }
  }
}
