-- Institutions
INSERT INTO Institution SET id = 'i1', name = 'MIT'
INSERT INTO Institution SET id = 'i2', name = 'Stanford'
INSERT INTO Institution SET id = 'i3', name = 'Oxford'
INSERT INTO Institution SET id = 'i4', name = 'ETH Zurich'
-- Researchers
INSERT INTO Researcher SET id = 'r1', name = 'Alice Chen', embedding = [0.9, 0.1, 0.1, 0.1]
INSERT INTO Researcher SET id = 'r2', name = 'Bob Kim', embedding = [0.8, 0.2, 0.1, 0.1]
INSERT INTO Researcher SET id = 'r3', name = 'Carol Davis', embedding = [0.1, 0.9, 0.1, 0.1]
INSERT INTO Researcher SET id = 'r4', name = 'David Lee', embedding = [0.1, 0.1, 0.9, 0.1]
INSERT INTO Researcher SET id = 'r5', name = 'Eve Patel', embedding = [0.5, 0.5, 0.1, 0.1]
-- Topics
INSERT INTO Topic SET id = 't1', name = 'Distributed Systems', embedding = [0.9, 0.1, 0.1, 0.1]
INSERT INTO Topic SET id = 't2', name = 'Machine Learning', embedding = [0.8, 0.2, 0.1, 0.1]
INSERT INTO Topic SET id = 't3', name = 'Graph Databases', embedding = [0.7, 0.3, 0.1, 0.1]
INSERT INTO Topic SET id = 't4', name = 'Bioinformatics', embedding = [0.1, 0.9, 0.1, 0.1]
INSERT INTO Topic SET id = 't5', name = 'Quantum Computing', embedding = [0.1, 0.1, 0.9, 0.1]
INSERT INTO Topic SET id = 't6', name = 'Knowledge Graphs', embedding = [0.6, 0.4, 0.1, 0.1]
-- Papers
INSERT INTO Paper SET id = 'p1', year = 2021, title = 'Consensus Algorithms in Distributed Systems', abstract = 'This paper surveys consensus algorithms for distributed systems including Paxos and Raft protocols for fault-tolerant replication.', embedding = [0.9, 0.1, 0.1, 0.1]
INSERT INTO Paper SET id = 'p2', year = 2022, title = 'Graph Neural Networks for Knowledge Representation', abstract = 'We present graph neural network architectures for knowledge graph embedding, reasoning, and link prediction at scale.', embedding = [0.8, 0.2, 0.1, 0.1]
INSERT INTO Paper SET id = 'p3', year = 2022, title = 'Vector Databases and Approximate Nearest Neighbor Search', abstract = 'A comparative study of vector database systems supporting approximate nearest neighbor search and embedding retrieval at scale.', embedding = [0.7, 0.3, 0.1, 0.1]
INSERT INTO Paper SET id = 'p4', year = 2023, title = 'Multi-Model Databases for Complex Applications', abstract = 'We analyze multi-model database systems that unify graph, document, and vector storage without impedance mismatch.', embedding = [0.8, 0.1, 0.2, 0.1]
INSERT INTO Paper SET id = 'p5', year = 2022, title = 'Federated Learning over Graph-Structured Data', abstract = 'Federated learning methods applied to distributed graph-structured datasets across privacy-preserving node partitions.', embedding = [0.7, 0.2, 0.2, 0.1]
INSERT INTO Paper SET id = 'p6', year = 2021, title = 'Protein-Protein Interaction Networks', abstract = 'A graph-based analysis of protein-protein interaction networks reveals functional modules in cellular biology.', embedding = [0.1, 0.9, 0.1, 0.1]
INSERT INTO Paper SET id = 'p7', year = 2023, title = 'Quantum Entanglement in Noisy Systems', abstract = 'Studying quantum entanglement and coherence properties under realistic noise conditions using density matrix formalism.', embedding = [0.1, 0.1, 0.9, 0.1]
INSERT INTO Paper SET id = 'p8', year = 2023, title = 'Knowledge Graph Completion with Embeddings', abstract = 'Embedding-based methods for knowledge graph completion enable scalable link prediction and relation inference tasks.', embedding = [0.8, 0.2, 0.1, 0.1]
INSERT INTO Paper SET id = 'p9', year = 2023, title = 'Distributed Consensus for Blockchain Networks', abstract = 'Consensus mechanisms designed for permissioned blockchain networks with Byzantine fault tolerance guarantees.', embedding = [0.9, 0.1, 0.1, 0.2]
INSERT INTO Paper SET id = 'p10', year = 2024, title = 'RAG Systems with Knowledge Graph Augmentation', abstract = 'Retrieval-augmented generation combined with knowledge graph traversal improves factual accuracy by 2.8x over vector-only retrieval.', embedding = [0.7, 0.3, 0.1, 0.1]
-- AFFILIATED_WITH edges (Researcher -> Institution)
CREATE EDGE AFFILIATED_WITH FROM (SELECT FROM Researcher WHERE id = 'r1') TO (SELECT FROM Institution WHERE id = 'i1')
CREATE EDGE AFFILIATED_WITH FROM (SELECT FROM Researcher WHERE id = 'r2') TO (SELECT FROM Institution WHERE id = 'i2')
CREATE EDGE AFFILIATED_WITH FROM (SELECT FROM Researcher WHERE id = 'r3') TO (SELECT FROM Institution WHERE id = 'i1')
CREATE EDGE AFFILIATED_WITH FROM (SELECT FROM Researcher WHERE id = 'r4') TO (SELECT FROM Institution WHERE id = 'i3')
CREATE EDGE AFFILIATED_WITH FROM (SELECT FROM Researcher WHERE id = 'r5') TO (SELECT FROM Institution WHERE id = 'i2')
-- CO_AUTHORED edges (Researcher -> Paper) — r1 and r5 both authored p1 (deliberate overlap for Query 1)
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r1') TO (SELECT FROM Paper WHERE id = 'p1')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r1') TO (SELECT FROM Paper WHERE id = 'p4')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r1') TO (SELECT FROM Paper WHERE id = 'p9')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r2') TO (SELECT FROM Paper WHERE id = 'p2')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r2') TO (SELECT FROM Paper WHERE id = 'p5')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r2') TO (SELECT FROM Paper WHERE id = 'p8')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r3') TO (SELECT FROM Paper WHERE id = 'p6')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r4') TO (SELECT FROM Paper WHERE id = 'p7')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r5') TO (SELECT FROM Paper WHERE id = 'p1')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r5') TO (SELECT FROM Paper WHERE id = 'p3')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r5') TO (SELECT FROM Paper WHERE id = 'p10')
-- CITES edges (Paper -> Paper) — creates citation graph for GraphRAG (Query 5)
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p2') TO (SELECT FROM Paper WHERE id = 'p1')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p3') TO (SELECT FROM Paper WHERE id = 'p2')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p4') TO (SELECT FROM Paper WHERE id = 'p1')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p4') TO (SELECT FROM Paper WHERE id = 'p3')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p5') TO (SELECT FROM Paper WHERE id = 'p2')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p8') TO (SELECT FROM Paper WHERE id = 'p2')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p8') TO (SELECT FROM Paper WHERE id = 'p3')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p9') TO (SELECT FROM Paper WHERE id = 'p1')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p10') TO (SELECT FROM Paper WHERE id = 'p3')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p10') TO (SELECT FROM Paper WHERE id = 'p8')
-- COVERS edges (Paper -> Topic)
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p1') TO (SELECT FROM Topic WHERE id = 't1')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p2') TO (SELECT FROM Topic WHERE id = 't2')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p2') TO (SELECT FROM Topic WHERE id = 't6')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p3') TO (SELECT FROM Topic WHERE id = 't3')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p3') TO (SELECT FROM Topic WHERE id = 't2')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p4') TO (SELECT FROM Topic WHERE id = 't3')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p4') TO (SELECT FROM Topic WHERE id = 't1')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p5') TO (SELECT FROM Topic WHERE id = 't2')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p5') TO (SELECT FROM Topic WHERE id = 't1')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p6') TO (SELECT FROM Topic WHERE id = 't4')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p7') TO (SELECT FROM Topic WHERE id = 't5')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p8') TO (SELECT FROM Topic WHERE id = 't6')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p9') TO (SELECT FROM Topic WHERE id = 't1')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p10') TO (SELECT FROM Topic WHERE id = 't6')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p10') TO (SELECT FROM Topic WHERE id = 't2')
-- PaperActivity documents for trending query (varied counts so results are ordered meaningfully)
INSERT INTO PaperActivity SET paperId = 'p1', citationCount = 15, ts = date()
INSERT INTO PaperActivity SET paperId = 'p2', citationCount = 22, ts = date()
INSERT INTO PaperActivity SET paperId = 'p3', citationCount = 18, ts = date()
INSERT INTO PaperActivity SET paperId = 'p8', citationCount = 30, ts = date()
INSERT INTO PaperActivity SET paperId = 'p10', citationCount = 25, ts = date()
INSERT INTO PaperActivity SET paperId = 'p1', citationCount = 8, ts = date()
INSERT INTO PaperActivity SET paperId = 'p2', citationCount = 10, ts = date()
INSERT INTO PaperActivity SET paperId = 'p9', citationCount = 12, ts = date()
INSERT INTO PaperActivity SET paperId = 'p3', citationCount = 7, ts = date()
INSERT INTO PaperActivity SET paperId = 'p5', citationCount = 5, ts = date()
