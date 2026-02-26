package com.arcadedb.examples;

import dev.langchain4j.community.store.embedding.neo4j.Neo4jEmbeddingStore;
import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.embedding.onnx.allminilml6v2.AllMiniLmL6V2EmbeddingModel;
import dev.langchain4j.rag.content.Content;
import dev.langchain4j.rag.content.retriever.EmbeddingStoreContentRetriever;
import dev.langchain4j.rag.query.Query;

import java.util.List;

public class GraphRAGContentRetriever {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final String PORT     = System.getenv().getOrDefault("ARCADEDB_BOLT_PORT", "2424");
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    EmbeddingModel embeddingModel = new AllMiniLmL6V2EmbeddingModel();

    String boltUrl = "bolt://" + HOST + ":" + PORT;
    Neo4jEmbeddingStore store = Neo4jEmbeddingStore.builder()
        .withBasicAuth(boltUrl, USER, PASSWORD)
        .dimension(embeddingModel.dimension())
        .label("RAGChunk")
        .indexName("rag_chunk_index")
        .build();

    // Ingest sample chunks
    String[] texts = {
        "GraphRAG combines knowledge graphs with vector search to improve retrieval accuracy.",
        "By traversing entity relationships, the system discovers context that pure vector similarity would miss.",
        "Vector similarity search uses embedding models to encode text into high-dimensional vectors.",
        "Approximate nearest neighbor algorithms like HNSW trade small accuracy losses for dramatic speed improvements.",
        "Microservices decompose applications into small, independently deployable services.",
        "Building a knowledge graph requires extracting entities and relationships from documents."
    };

    for (String text : texts) {
      TextSegment segment = TextSegment.from(text);
      Embedding embedding = embeddingModel.embed(segment).content();
      store.add(embedding, segment);
    }

    System.out.println("Ingested " + texts.length + " chunks into RAGChunk nodes.\n");

    // Build content retriever pipeline
    EmbeddingStoreContentRetriever retriever = EmbeddingStoreContentRetriever.builder()
        .embeddingStore(store)
        .embeddingModel(embeddingModel)
        .maxResults(3)
        .minScore(0.5)
        .build();

    // Run queries
    String[] queries = {
        "How does graph-based retrieval work?",
        "What are vector embeddings?",
        "Tell me about microservices architecture"
    };

    for (String q : queries) {
      System.out.println("Query: \"" + q + "\"");
      List<Content> results = retriever.retrieve(new Query(q));
      if (results.isEmpty()) {
        System.out.println("  (no results above min score)\n");
      } else {
        for (Content content : results) {
          System.out.println("  -> " + content.textSegment().text());
        }
        System.out.println();
      }
    }
  }
}
