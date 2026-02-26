-- ── Chunks (internal documentation) ─────────────────────────────────────────
-- Getting Started with GraphRAG (graph-heavy topic)
INSERT INTO Chunk SET content = 'GraphRAG combines knowledge graphs with vector search to improve retrieval accuracy. By traversing entity relationships, the system discovers context that pure vector similarity would miss.', source = 'Getting Started with GraphRAG', chunkIndex = 0, embedding = [0.9, 0.2, 0.1, 0.1];
INSERT INTO Chunk SET content = 'Building a knowledge graph requires extracting entities and relationships from documents. Named entity recognition and relationship extraction are key preprocessing steps.', source = 'Getting Started with GraphRAG', chunkIndex = 1, embedding = [0.8, 0.1, 0.2, 0.1];
-- Microservices Architecture Guide (architecture-heavy topic)
INSERT INTO Chunk SET content = 'Microservices decompose applications into small, independently deployable services. Each service owns its data and communicates via well-defined APIs.', source = 'Microservices Architecture Guide', chunkIndex = 0, embedding = [0.1, 0.1, 0.9, 0.2];
INSERT INTO Chunk SET content = 'Service mesh patterns like sidecar proxies handle cross-cutting concerns including observability, security, and traffic management across microservices.', source = 'Microservices Architecture Guide', chunkIndex = 1, embedding = [0.1, 0.1, 0.8, 0.3];
-- Vector Search Best Practices (vector-heavy topic)
INSERT INTO Chunk SET content = 'Vector similarity search uses embedding models to encode text into high-dimensional vectors. Cosine distance is the most common similarity metric for text embeddings.', source = 'Vector Search Best Practices', chunkIndex = 0, embedding = [0.2, 0.9, 0.1, 0.1];
INSERT INTO Chunk SET content = 'Approximate nearest neighbor algorithms like HNSW and DiskANN trade small accuracy losses for dramatic speed improvements on large vector datasets.', source = 'Vector Search Best Practices', chunkIndex = 1, embedding = [0.1, 0.8, 0.1, 0.2];
-- Team Onboarding Handbook (general topic)
INSERT INTO Chunk SET content = 'New engineers at ArcadeSoft join a team and are assigned a mentor. The onboarding process covers codebase orientation, tooling setup, and architecture overview.', source = 'Team Onboarding Handbook', chunkIndex = 0, embedding = [0.2, 0.2, 0.3, 0.8];
INSERT INTO Chunk SET content = 'The Platform Team maintains shared infrastructure including the knowledge graph pipeline and vector search service. The Research Team explores new retrieval techniques.', source = 'Team Onboarding Handbook', chunkIndex = 1, embedding = [0.3, 0.3, 0.2, 0.7];

-- ── Entities ────────────────────────────────────────────────────────────────
-- Persons
INSERT INTO Person SET name = 'Alice Chen';
INSERT INTO Person SET name = 'Bob Martinez';
INSERT INTO Person SET name = 'Carol Wu';
INSERT INTO Person SET name = 'Dave Park';
-- Concepts
INSERT INTO Concept SET name = 'GraphRAG';
INSERT INTO Concept SET name = 'Vector Search';
INSERT INTO Concept SET name = 'Microservices';
INSERT INTO Concept SET name = 'Knowledge Graph';
-- Organizations
INSERT INTO Organization SET name = 'ArcadeSoft';
INSERT INTO Organization SET name = 'Platform Team';
INSERT INTO Organization SET name = 'Research Team';

-- ── MENTIONS edges (Chunk -> Entity) ────────────────────────────────────────
-- GraphRAG doc chunks mention GraphRAG and Knowledge Graph concepts
CREATE EDGE MENTIONS FROM (SELECT FROM Chunk WHERE source = 'Getting Started with GraphRAG' AND chunkIndex = 0) TO (SELECT FROM Concept WHERE name = 'GraphRAG');
CREATE EDGE MENTIONS FROM (SELECT FROM Chunk WHERE source = 'Getting Started with GraphRAG' AND chunkIndex = 0) TO (SELECT FROM Concept WHERE name = 'Vector Search');
CREATE EDGE MENTIONS FROM (SELECT FROM Chunk WHERE source = 'Getting Started with GraphRAG' AND chunkIndex = 1) TO (SELECT FROM Concept WHERE name = 'GraphRAG');
CREATE EDGE MENTIONS FROM (SELECT FROM Chunk WHERE source = 'Getting Started with GraphRAG' AND chunkIndex = 1) TO (SELECT FROM Concept WHERE name = 'Knowledge Graph');
-- Vector Search doc chunks mention Vector Search concept
CREATE EDGE MENTIONS FROM (SELECT FROM Chunk WHERE source = 'Vector Search Best Practices' AND chunkIndex = 0) TO (SELECT FROM Concept WHERE name = 'Vector Search');
CREATE EDGE MENTIONS FROM (SELECT FROM Chunk WHERE source = 'Vector Search Best Practices' AND chunkIndex = 1) TO (SELECT FROM Concept WHERE name = 'Vector Search');
-- Microservices doc chunks mention Microservices concept
CREATE EDGE MENTIONS FROM (SELECT FROM Chunk WHERE source = 'Microservices Architecture Guide' AND chunkIndex = 0) TO (SELECT FROM Concept WHERE name = 'Microservices');
CREATE EDGE MENTIONS FROM (SELECT FROM Chunk WHERE source = 'Microservices Architecture Guide' AND chunkIndex = 1) TO (SELECT FROM Concept WHERE name = 'Microservices');
-- Onboarding doc mentions teams and people
CREATE EDGE MENTIONS FROM (SELECT FROM Chunk WHERE source = 'Team Onboarding Handbook' AND chunkIndex = 0) TO (SELECT FROM Organization WHERE name = 'ArcadeSoft');
CREATE EDGE MENTIONS FROM (SELECT FROM Chunk WHERE source = 'Team Onboarding Handbook' AND chunkIndex = 1) TO (SELECT FROM Organization WHERE name = 'Platform Team');
CREATE EDGE MENTIONS FROM (SELECT FROM Chunk WHERE source = 'Team Onboarding Handbook' AND chunkIndex = 1) TO (SELECT FROM Organization WHERE name = 'Research Team');
CREATE EDGE MENTIONS FROM (SELECT FROM Chunk WHERE source = 'Team Onboarding Handbook' AND chunkIndex = 1) TO (SELECT FROM Concept WHERE name = 'Knowledge Graph');
CREATE EDGE MENTIONS FROM (SELECT FROM Chunk WHERE source = 'Team Onboarding Handbook' AND chunkIndex = 1) TO (SELECT FROM Concept WHERE name = 'Vector Search');

-- ── RELATES_TO edges (Entity -> Entity) ─────────────────────────────────────
CREATE EDGE RELATES_TO FROM (SELECT FROM Concept WHERE name = 'GraphRAG') TO (SELECT FROM Concept WHERE name = 'Vector Search');
CREATE EDGE RELATES_TO FROM (SELECT FROM Concept WHERE name = 'GraphRAG') TO (SELECT FROM Concept WHERE name = 'Knowledge Graph');
CREATE EDGE RELATES_TO FROM (SELECT FROM Concept WHERE name = 'Microservices') TO (SELECT FROM Concept WHERE name = 'Knowledge Graph');

-- ── WORKS_AT edges (Person -> Organization) ─────────────────────────────────
CREATE EDGE WORKS_AT FROM (SELECT FROM Person WHERE name = 'Alice Chen') TO (SELECT FROM Organization WHERE name = 'Research Team');
CREATE EDGE WORKS_AT FROM (SELECT FROM Person WHERE name = 'Bob Martinez') TO (SELECT FROM Organization WHERE name = 'Platform Team');
CREATE EDGE WORKS_AT FROM (SELECT FROM Person WHERE name = 'Carol Wu') TO (SELECT FROM Organization WHERE name = 'ArcadeSoft');
CREATE EDGE WORKS_AT FROM (SELECT FROM Person WHERE name = 'Dave Park') TO (SELECT FROM Organization WHERE name = 'Platform Team');

-- ── AUTHORED edges (Person -> Chunk) ────────────────────────────────────────
CREATE EDGE AUTHORED FROM (SELECT FROM Person WHERE name = 'Alice Chen') TO (SELECT FROM Chunk WHERE source = 'Getting Started with GraphRAG' AND chunkIndex = 0);
CREATE EDGE AUTHORED FROM (SELECT FROM Person WHERE name = 'Alice Chen') TO (SELECT FROM Chunk WHERE source = 'Getting Started with GraphRAG' AND chunkIndex = 1);
CREATE EDGE AUTHORED FROM (SELECT FROM Person WHERE name = 'Bob Martinez') TO (SELECT FROM Chunk WHERE source = 'Microservices Architecture Guide' AND chunkIndex = 0);
CREATE EDGE AUTHORED FROM (SELECT FROM Person WHERE name = 'Bob Martinez') TO (SELECT FROM Chunk WHERE source = 'Microservices Architecture Guide' AND chunkIndex = 1);
CREATE EDGE AUTHORED FROM (SELECT FROM Person WHERE name = 'Alice Chen') TO (SELECT FROM Chunk WHERE source = 'Vector Search Best Practices' AND chunkIndex = 0);
CREATE EDGE AUTHORED FROM (SELECT FROM Person WHERE name = 'Alice Chen') TO (SELECT FROM Chunk WHERE source = 'Vector Search Best Practices' AND chunkIndex = 1);
CREATE EDGE AUTHORED FROM (SELECT FROM Person WHERE name = 'Carol Wu') TO (SELECT FROM Chunk WHERE source = 'Team Onboarding Handbook' AND chunkIndex = 0);
CREATE EDGE AUTHORED FROM (SELECT FROM Person WHERE name = 'Carol Wu') TO (SELECT FROM Chunk WHERE source = 'Team Onboarding Handbook' AND chunkIndex = 1);
