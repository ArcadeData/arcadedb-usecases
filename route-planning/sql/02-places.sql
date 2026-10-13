-- Look junctions up by their DIMACS id, and name the ones nearest to a few cities
CREATE INDEX IF NOT EXISTS ON Junction (id) UNIQUE;
UPDATE Junction SET name = 'Tallahassee' WHERE id = 472033;
UPDATE Junction SET name = 'Coral Gables' WHERE id = 624638;
UPDATE Junction SET name = 'Orlando' WHERE id = 679162;
UPDATE Junction SET name = 'Tampa' WHERE id = 343370;
UPDATE Junction SET name = 'Jacksonville' WHERE id = 221045;
UPDATE Junction SET name = 'Miami' WHERE id = 578831;
UPDATE Junction SET name = 'Gainesville' WHERE id = 13522;
UPDATE Junction SET name = 'Pensacola' WHERE id = 257549;
CREATE INDEX IF NOT EXISTS ON Junction (name) NOTUNIQUE;
