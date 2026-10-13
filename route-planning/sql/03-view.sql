-- A Graph Analytical View over the roads, keeping one Customizable Contraction Hierarchy per cost
CREATE GRAPH ANALYTICAL VIEW IF NOT EXISTS Florida EDGE TYPES (ROAD) UPDATE MODE SYNCHRONOUS CCH (km, minutes);
