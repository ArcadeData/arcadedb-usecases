-- Users
INSERT INTO User SET id = 'u1', embedding = [0.9, 0.1, 0.1, 0.1];
INSERT INTO User SET id = 'u2', embedding = [0.5, 0.5, 0.1, 0.1];
INSERT INTO User SET id = 'u3', embedding = [0.1, 0.9, 0.1, 0.1];
INSERT INTO User SET id = 'u4', embedding = [0.1, 0.1, 0.9, 0.1];
INSERT INTO User SET id = 'u5', embedding = [0.4, 0.3, 0.2, 0.1];
-- Products (Electronics)
INSERT INTO Product SET name = 'Laptop', category = 'Electronics', price = 999.99, inStock = true, embedding = [0.9, 0.1, 0.1, 0.1];
INSERT INTO Product SET name = 'Phone', category = 'Electronics', price = 699.99, inStock = true, embedding = [0.8, 0.1, 0.2, 0.1];
INSERT INTO Product SET name = 'Headphones', category = 'Electronics', price = 199.99, inStock = true, embedding = [0.7, 0.2, 0.2, 0.1];
INSERT INTO Product SET name = 'Keyboard', category = 'Electronics', price = 99.99, inStock = true, embedding = [0.8, 0.2, 0.1, 0.1];
INSERT INTO Product SET name = 'Monitor', category = 'Electronics', price = 399.99, inStock = true, embedding = [0.9, 0.1, 0.1, 0.2];
-- Products (Sports)
INSERT INTO Product SET name = 'Running Shoes', category = 'Sports', price = 89.99, inStock = true, embedding = [0.1, 0.9, 0.1, 0.1];
INSERT INTO Product SET name = 'Yoga Mat', category = 'Sports', price = 29.99, inStock = true, embedding = [0.1, 0.8, 0.2, 0.1];
INSERT INTO Product SET name = 'Water Bottle', category = 'Sports', price = 19.99, inStock = true, embedding = [0.2, 0.7, 0.1, 0.1];
INSERT INTO Product SET name = 'Tennis Racket', category = 'Sports', price = 59.99, inStock = true, embedding = [0.1, 0.9, 0.1, 0.2];
INSERT INTO Product SET name = 'Jump Rope', category = 'Sports', price = 14.99, inStock = false, embedding = [0.1, 0.8, 0.1, 0.2];
-- Shows
INSERT INTO Show SET title = 'Action Movie', genre = 'Action', embedding = [0.3, 0.2, 0.9, 0.1];
INSERT INTO Show SET title = 'Comedy Show', genre = 'Comedy', embedding = [0.1, 0.1, 0.8, 0.2];
INSERT INTO Show SET title = 'Documentary', genre = 'Documentary', embedding = [0.2, 0.3, 0.7, 0.1];
INSERT INTO Show SET title = 'Drama Series', genre = 'Drama', embedding = [0.1, 0.2, 0.8, 0.1];
INSERT INTO Show SET title = 'Sci-Fi Movie', genre = 'Sci-Fi', embedding = [0.4, 0.1, 0.9, 0.1];
-- PURCHASED edges (u1+u2 share Phone and Headphones -> u1 will get Running Shoes via collab)
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u1') TO (SELECT FROM Product WHERE name = 'Laptop');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u1') TO (SELECT FROM Product WHERE name = 'Phone');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u1') TO (SELECT FROM Product WHERE name = 'Headphones');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u2') TO (SELECT FROM Product WHERE name = 'Phone');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u2') TO (SELECT FROM Product WHERE name = 'Headphones');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u2') TO (SELECT FROM Product WHERE name = 'Running Shoes');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u3') TO (SELECT FROM Product WHERE name = 'Running Shoes');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u3') TO (SELECT FROM Product WHERE name = 'Yoga Mat');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u3') TO (SELECT FROM Product WHERE name = 'Tennis Racket');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u5') TO (SELECT FROM Product WHERE name = 'Laptop');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u5') TO (SELECT FROM Product WHERE name = 'Running Shoes');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u5') TO (SELECT FROM Product WHERE name = 'Water Bottle');
-- WATCHED edges (u1+u2 both watched Action Movie -> u1 gets Comedy Show via collab)
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u1') TO (SELECT FROM Show WHERE title = 'Action Movie');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u1') TO (SELECT FROM Show WHERE title = 'Sci-Fi Movie');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u2') TO (SELECT FROM Show WHERE title = 'Action Movie');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u2') TO (SELECT FROM Show WHERE title = 'Comedy Show');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u3') TO (SELECT FROM Show WHERE title = 'Documentary');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u4') TO (SELECT FROM Show WHERE title = 'Comedy Show');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u4') TO (SELECT FROM Show WHERE title = 'Drama Series');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u5') TO (SELECT FROM Show WHERE title = 'Action Movie');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u5') TO (SELECT FROM Show WHERE title = 'Documentary');
-- INTERACTED edges
CREATE EDGE INTERACTED FROM (SELECT FROM User WHERE id = 'u1') TO (SELECT FROM Product WHERE name = 'Laptop');
CREATE EDGE INTERACTED FROM (SELECT FROM User WHERE id = 'u1') TO (SELECT FROM Product WHERE name = 'Phone');
CREATE EDGE INTERACTED FROM (SELECT FROM User WHERE id = 'u2') TO (SELECT FROM Product WHERE name = 'Phone');
CREATE EDGE INTERACTED FROM (SELECT FROM User WHERE id = 'u2') TO (SELECT FROM Product WHERE name = 'Running Shoes');
CREATE EDGE INTERACTED FROM (SELECT FROM User WHERE id = 'u3') TO (SELECT FROM Product WHERE name = 'Yoga Mat');
CREATE EDGE INTERACTED FROM (SELECT FROM User WHERE id = 'u5') TO (SELECT FROM Product WHERE name = 'Laptop');
CREATE EDGE INTERACTED FROM (SELECT FROM User WHERE id = 'u5') TO (SELECT FROM Product WHERE name = 'Water Bottle');
-- ProductInteraction documents for trending query
INSERT INTO ProductInteraction SET productId = 'Laptop', purchaseCount = 12, ts = date();
INSERT INTO ProductInteraction SET productId = 'Phone', purchaseCount = 20, ts = date();
INSERT INTO ProductInteraction SET productId = 'Running Shoes', purchaseCount = 35, ts = date();
INSERT INTO ProductInteraction SET productId = 'Headphones', purchaseCount = 8, ts = date();
INSERT INTO ProductInteraction SET productId = 'Yoga Mat', purchaseCount = 15, ts = date();
INSERT INTO ProductInteraction SET productId = 'Laptop', purchaseCount = 3, ts = date();
INSERT INTO ProductInteraction SET productId = 'Running Shoes', purchaseCount = 18, ts = date();
INSERT INTO ProductInteraction SET productId = 'Phone', purchaseCount = 9, ts = date();
